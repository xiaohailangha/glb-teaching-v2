import 'dart:convert';

import 'package:http/http.dart' as http;

class LearnerAccount {
  const LearnerAccount({
    required this.id,
    required this.nickname,
    required this.phoneMasked,
  });
  final String id, nickname, phoneMasked;
  factory LearnerAccount.fromJson(Map data) => LearnerAccount(
    id: data['id'] as String,
    nickname: data['nickname'] as String,
    phoneMasked: data['phoneMasked'] as String,
  );
}

class AuthFailure implements Exception {
  const AuthFailure(this.message, {this.retryAfter = 0});
  final String message;
  final int retryAfter;
  @override
  String toString() => message;
}

class AuthApi {
  AuthApi({http.Client? client, Uri? origin})
    : client = client ?? http.Client(),
      origin = origin ?? Uri.base;
  final http.Client client;
  final Uri origin;
  Future<Map<String, dynamic>> request(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? data,
  }) async {
    try {
      final request = http.Request(method, origin.resolve('/api/auth/$path'));
      if (data != null) {
        request.headers['Content-Type'] = 'application/json';
        request.body = jsonEncode(data);
      }
      final response = await http.Response.fromStream(
        await client.send(request).timeout(const Duration(seconds: 20)),
      );
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode >= 400) {
        throw AuthFailure(
          body['error'] as String? ?? '暂时无法完成，请稍后再试',
          retryAfter: (body['retryAfter'] as num?)?.toInt() ?? 0,
        );
      }
      return body;
    } on AuthFailure {
      rethrow;
    } catch (_) {
      throw const AuthFailure('连接暂时不顺畅，请稍后重试');
    }
  }

  Future<LearnerAccount?> me() async {
    final data = await request('me');
    return data['user'] is Map
        ? LearnerAccount.fromJson(data['user'] as Map)
        : null;
  }

  Future<void> rename(String nickname) async =>
      request('me', method: 'PATCH', data: {'nickname': nickname});
  Future<void> logout() async => request('logout', method: 'POST', data: {});
  void dispose() => client.close();
}
