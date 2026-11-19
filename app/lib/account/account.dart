// The optional BloomBack account (Chi's screen 2, thread 0003): email one-time code, Sign in with Apple, or Google.
// It holds the sign-in, a first name, BloomBack Pro and the coach's allowance. Plans, check-ins, the garden, sleep
// and steps stay on this phone; "Try without an account" keeps everything working except the coach.
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api.dart';
import 'providers.dart';

/// Where the session token is kept: the Keychain / Android Keystore on a phone, memory in tests.
abstract class TokenVault {
  Future<String?> read();
  Future<void> write(String? token);
}

class SecureTokenVault implements TokenVault {
  static const _key = 'bb_session';
  final _storage = const FlutterSecureStorage();
  @override
  Future<String?> read() async {
    try {
      return await _storage.read(key: _key);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String? token) async {
    try {
      token == null ? await _storage.delete(key: _key) : await _storage.write(key: _key, value: token);
    } catch (_) {/* the session is lost on restart; signing in again fixes it */}
  }
}

class MemoryTokenVault implements TokenVault {
  String? token;
  @override
  Future<String?> read() async => token;
  @override
  Future<void> write(String? t) async => token = t;
}

class AccountView {
  const AccountView({required this.id, this.email, this.name, this.via = const []});
  final int id;
  final String? email;
  final String? name;
  final List<String> via; // 'email' | 'apple' | 'google'

  static AccountView? from(Object? j) => j is Map
      ? AccountView(
          id: (j['id'] as num?)?.toInt() ?? 0,
          email: j['email'] as String?,
          name: j['name'] as String?,
          via: [for (final v in (j['via'] as List? ?? const [])) '$v'],
        )
      : null;
}

/// What the coach allows, as the server counts it.
class Standing {
  const Standing({this.pro = false, this.lifetime = false, this.proUntil, this.freeAsksLeft = 0, this.proAsksLeftToday = 0});
  final bool pro;
  final bool lifetime;
  final DateTime? proUntil;
  final int freeAsksLeft;
  final int proAsksLeftToday;

  int get asksLeft => pro ? proAsksLeftToday : freeAsksLeft;

  static Standing? from(Object? j) {
    if (j is! Map) return null;
    final p = j['pro'] is Map ? j['pro'] as Map : const {};
    final until = p['until'];
    return Standing(
      pro: p['active'] == true,
      lifetime: p['lifetime'] == true,
      proUntil: until is num ? DateTime.fromMillisecondsSinceEpoch(until.toInt()) : null,
      freeAsksLeft: (j['freeAsksLeft'] as num?)?.toInt() ?? 0,
      proAsksLeftToday: (j['proAsksLeftToday'] as num?)?.toInt() ?? 0,
    );
  }
}

/// One habit the coach pointed to, with its source (from the server's copy of Chi's list).
class CoachHabit {
  const CoachHabit(this.id, this.title, this.source, this.link);
  final String id;
  final String title;
  final String source;
  final String? link;
}

class CoachAnswer {
  const CoachAnswer({required this.kind, required this.text, required this.habits, required this.note, this.demo = false});
  final String kind; // 'answer' | 'see_doctor'
  final String text;
  final List<CoachHabit> habits;
  final String note;
  final bool demo;

  static CoachAnswer from(Map j) => CoachAnswer(
        kind: '${j['kind']}',
        text: '${j['text'] ?? ''}',
        habits: [
          for (final h in (j['habits'] as List? ?? const []))
            if (h is Map) CoachHabit('${h['id']}', '${h['title']}', '${h['source']}', h['link'] as String?),
        ],
        note: '${j['note'] ?? ''}',
        demo: j['demo'] == true,
      );
}

class Account extends ChangeNotifier {
  Account({BBApi? api, TokenVault? vault, SignInProviders? providers})
      : api = api ?? BBApi(),
        vault = vault ?? SecureTokenVault(),
        providers = providers ?? (kIsWeb ? const NoSignInProviders() : DeviceSignInProviders());

  final BBApi api;
  final TokenVault vault;
  final SignInProviders providers;

  String? _token;
  AccountView? view;
  Standing standing = const Standing();
  bool busy = false;

  bool get signedIn => _token != null && view != null;

  /// Accounts need the phone app (the web demo has no server connection).
  bool get available => !kIsWeb;

  /// At start: a kept session is checked with the server. Offline keeps it; a refused session is dropped.
  Future<void> restore() async {
    _token = await vault.read();
    if (_token == null) return;
    try {
      _take(await api.send('GET', '/v1/me', token: _token));
    } on ApiProblem catch (p) {
      if (p.status == 401) await _drop();
    }
  }

  void _take(Map<String, Object?> body) {
    final v = AccountView.from(body['account']);
    if (v != null) view = v;
    final s = Standing.from(body['standing']);
    if (s != null) standing = s;
    notifyListeners();
  }

  Future<void> _signedIn(Map<String, Object?> body) async {
    _token = body['token'] as String?;
    await vault.write(_token);
    _take(body);
  }

  Future<void> _drop() async {
    _token = null;
    view = null;
    standing = const Standing();
    await vault.write(null);
    notifyListeners();
  }

  Future<T> _busy<T>(Future<T> Function() f) async {
    busy = true;
    notifyListeners();
    try {
      return await f();
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  // ---------- sign-in ----------

  /// Sends a 6-digit code to [email]. Throws ApiProblem.
  Future<void> emailStart(String email) => _busy(() async {
        await api.send('POST', '/v1/auth/email/start', json: {'email': email.trim()});
      });

  Future<void> emailVerify(String email, String code, {String? name}) => _busy(() async {
        await _signedIn(await api.send('POST', '/v1/auth/email/verify',
            json: {'email': email.trim(), 'code': code.trim(), if (name != null && name.trim().isNotEmpty) 'name': name.trim()}));
      });

  /// false = cancelled. Throws ApiProblem or ProviderTrouble.
  Future<bool> signInWithApple({String? name}) async {
    final t = await providers.apple();
    if (t == null) return false;
    await _busy(() async => _signedIn(await api.send('POST', '/v1/auth/apple',
        json: {'idToken': t.idToken, if ((name ?? t.name) != null) 'name': name?.trim().isNotEmpty == true ? name!.trim() : t.name})));
    return true;
  }

  Future<bool> signInWithGoogle({String? name}) async {
    final t = await providers.google();
    if (t == null) return false;
    await _busy(() async => _signedIn(await api.send('POST', '/v1/auth/google',
        json: {'idToken': t.idToken, if ((name ?? t.name) != null) 'name': name?.trim().isNotEmpty == true ? name!.trim() : t.name})));
    return true;
  }

  Future<void> signOut() async {
    final t = _token;
    await _drop();
    if (providers is DeviceSignInProviders) {
      try {
        await (providers as DeviceSignInProviders).signOutGoogle();
      } catch (_) {}
    }
    if (t != null) {
      try {
        await api.send('POST', '/v1/auth/signout', token: t);
      } catch (_) {/* signed out on the phone either way */}
    }
  }

  /// "Delete my account": deletes it on the server, then signs out here. Throws ApiProblem (nothing changes).
  Future<void> deleteAccount() => _busy(() async {
        await api.send('DELETE', '/v1/me', token: _token);
        await _drop();
      });

  Future<void> rename(String name) => _busy(() async {
        _take(await api.send('PATCH', '/v1/me', token: _token, json: {'name': name}));
      });

  Future<void> refresh() async {
    if (_token == null) return;
    try {
      _take(await api.send('GET', '/v1/me', token: _token));
    } on ApiProblem catch (p) {
      if (p.status == 401) await _drop();
    }
  }

  // ---------- Pro ----------

  /// Returns the days of Pro the code gave. Throws ApiProblem with the server's words.
  Future<int> redeem(String code) => _busy(() async {
        final body = await api.send('POST', '/v1/pro/redeem', token: _token, json: {'code': code});
        _take(body);
        return (body['days'] as num?)?.toInt() ?? 0;
      });

  /// A store purchase, sent for the server to check. Returns 'added' or 'already'.
  Future<String> claimPurchase(Map<String, Object?> proof) async {
    final body = await api.send('POST', '/v1/pro/purchase', token: _token, json: {'proof': proof});
    _take(body);
    return '${body['result']}';
  }

  // ---------- the coach ----------

  Future<CoachAnswer> ask(String question, {required List<String> habits, String? shift, String lang = 'en'}) async {
    final body = await api.send('POST', '/v1/ask',
        token: _token, json: {'question': question, 'habits': habits, 'shift': ?shift, 'lang': lang});
    final s = Standing.from(body['standing']);
    if (s != null) {
      standing = s;
      notifyListeners();
    }
    return CoachAnswer.from(body['answer'] as Map);
  }

  Future<void> report({required String reason, String? note, String? answer}) async {
    await api.send('POST', '/v1/report', token: _token, json: {
      'reason': reason,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      'answer': ?answer,
    });
  }
}
