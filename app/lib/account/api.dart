// The app's one line to our server (bloomback.cstsolution.com): sign-in, the account, BloomBack Pro and the coach.
// No model key, Brevo key or store secret lives on the phone. Health data (plan, check-ins, sleep, steps) never goes.
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

const _liveServer = 'https://bloomback.cstsolution.com';
const _chosenServer = String.fromEnvironment('BB_API');

/// Release builds talk to the live server; debug builds to a local one (`npm run dev` in server/, and
/// `adb reverse tcp:4652 tcp:4652` on Android) unless BB_API is given.
String get serverBase => _chosenServer.isNotEmpty ? _chosenServer : (kReleaseMode ? _liveServer : 'http://127.0.0.1:4652');

/// A refusal with the server's own words for it ("problem" is its id, for the app to react to).
class ApiProblem implements Exception {
  const ApiProblem(this.words, [this.problem = 'offline', this.status = 0]);
  final String words;
  final String problem;
  final int status;

  static const offlineWords = 'BloomBack could not reach its server. Check the connection and try again; '
      'your plan and garden work offline.';

  @override
  String toString() => words;
}

class BBApi {
  BBApi({http.Client? client, String? base})
      : _client = client ?? http.Client(),
        base = base ?? serverBase;

  final http.Client _client;
  final String base;

  Future<Map<String, Object?>> send(String method, String path, {String? token, Map<String, Object?>? json}) async {
    final req = http.Request(method, Uri.parse('$base$path'));
    if (token != null) req.headers['authorization'] = 'Bearer $token';
    if (json != null) {
      req.headers['content-type'] = 'application/json';
      req.body = jsonEncode(json);
    }
    late final http.Response res;
    late final Map<String, Object?> body;
    try {
      res = await http.Response.fromStream(await _client.send(req).timeout(const Duration(seconds: 60)));
      body = (jsonDecode(res.body) as Map).cast<String, Object?>();
    } catch (_) {
      throw const ApiProblem(ApiProblem.offlineWords);
    }
    if (res.statusCode >= 400) {
      throw ApiProblem('${body['words'] ?? ApiProblem.offlineWords}', '${body['problem'] ?? 'offline'}', res.statusCode);
    }
    return body;
  }
}
