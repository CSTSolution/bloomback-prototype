// A pretend BloomBack server for widget tests (package:http's MockClient): email codes, accounts, redeem codes and
// the coach, with the same JSON shapes as server/src/http.mjs. No network.
import 'dart:convert';

import 'package:bloomback/account/account.dart';
import 'package:bloomback/account/api.dart';
import 'package:bloomback/account/providers.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class FakeServer {
  final codes = <String, String>{}; // email -> code
  final asked = <Map<String, dynamic>>[];
  final reports = <Map<String, dynamic>>[];
  String? token;
  String? email;
  String? name;
  int freeLeft = 3;
  int? proDays;
  bool deleted = false;

  Map<String, Object?> get _me => {
        'account': {'id': 7, 'email': email, 'name': name, 'via': ['email']},
        'standing': {
          'pro': {'active': proDays != null, 'lifetime': false, 'until': proDays == null ? null : DateTime(2026, 12, 31).millisecondsSinceEpoch},
          'freeAsksLeft': freeLeft,
          'proAsksLeftToday': proDays == null ? 0 : 20,
        },
      };

  http.Response _ok(Object body) => http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json'});
  http.Response _no(int status, String problem, String words) =>
      http.Response(jsonEncode({'problem': problem, 'words': words}), status, headers: {'content-type': 'application/json'});

  late final client = MockClient((req) async {
    final body = req.body.isEmpty ? <String, dynamic>{} : (jsonDecode(req.body) as Map).cast<String, dynamic>();
    final authed = token != null && req.headers['authorization'] == 'Bearer $token';
    switch ('${req.method} ${req.url.path}') {
      case 'POST /v1/auth/email/start':
        codes['${body['email']}'.toLowerCase()] = '123456';
        return _ok({'sent': true, 'minutes': 10});
      case 'POST /v1/auth/email/verify':
        if (codes['${body['email']}'.toLowerCase()] != body['code']) {
          return _no(400, 'wrong_code', 'That code is not right. Check the latest email and try again.');
        }
        email = '${body['email']}'.toLowerCase();
        name = (body['name'] as String?) ?? name;
        token = 'bb1_test';
        return _ok({'token': token, 'made': true, ..._me});
      case 'GET /v1/me':
        return authed ? _ok(_me) : _no(401, 'signed_out', 'You are signed out.');
      case 'POST /v1/auth/signout':
        token = null;
        return _ok({'signedOut': true});
      case 'DELETE /v1/me':
        if (!authed) return _no(401, 'signed_out', 'You are signed out.');
        deleted = true;
        token = null;
        return _ok({'deleted': true});
      case 'POST /v1/pro/redeem':
        if (!authed) return _no(401, 'signed_out', 'You are signed out.');
        if (body['code'] != 'BB-TEST-CODE') return _no(400, 'code_unknown', 'That code is not known. Check the letters and try again.');
        proDays = 30;
        return _ok({'days': 30, ..._me});
      case 'POST /v1/ask':
        if (!authed) return _no(401, 'signed_out', 'You are signed out.');
        if (proDays == null && freeLeft == 0) {
          return _no(402, 'no_asks_left', 'Your 3 free questions are used. BloomBack Pro keeps the coach open.');
        }
        asked.add(body);
        if (proDays == null) freeLeft--;
        return _ok({
          'answer': {
            'kind': 'answer',
            'text': 'After a night shift you could go straight to bed when you get home.',
            'habits': [
              {'id': 'homeToBed', 'title': 'Straight to bed after the night shift, no chores first', 'source': 'NIOSH Training for Nurses on Shift Work and Long Work Hours, module 9', 'link': 'https://www.cdc.gov/niosh/docs/wp-solutions/2015-115/'},
            ],
            'note': 'BloomBack gives suggestions, not medical advice. If sleep problems last, talk to your doctor.',
            'demo': false,
          },
          ..._me,
        });
      case 'POST /v1/report':
        reports.add(body);
        return _ok({'ok': true});
    }
    return _no(404, 'not_found', 'Not found.');
  });

  Account account() => Account(
        api: BBApi(client: client, base: 'http://fake'),
        vault: MemoryTokenVault(),
        providers: const NoSignInProviders(),
      );
}
