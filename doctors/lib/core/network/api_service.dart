import 'package:dio/dio.dart';

import 'session_manager.dart';

class ApiService {
  ApiService._() {
    _dio = Dio(
      BaseOptions(
        baseUrl: 'http://192.168.1.6:5191/api',
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: <String, dynamic>{
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    );
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = SessionManager.instance.token?.trim();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          } else {
            options.headers.remove('Authorization');
          }
          handler.next(options);
        },
      ),
    );
  }

  static final ApiService instance = ApiService._();
  late final Dio _dio;

  Dio get client => _dio;

  /// Copies [SessionManager.token] onto the shared client so every request (including GET) sends `Authorization: Bearer …`.
  void syncAuthorizationHeaderFromSession() {
    final token = SessionManager.instance.token?.trim();
    if (token != null && token.isNotEmpty) {
      client.options.headers['Authorization'] = 'Bearer $token';
    } else {
      client.options.headers.remove('Authorization');
    }
  }

  /// Public origin for static files (uploads live under wwwroot, not under `/api`).
  String get publicOrigin {
    final u = Uri.parse(client.options.baseUrl);
    if (u.hasPort) {
      return '${u.scheme}://${u.host}:${u.port}';
    }
    return '${u.scheme}://${u.host}';
  }

  /// SignalR hub (no `/api` prefix). JWT via [HttpConnectionOptions.accessTokenFactory] or negotiate header.
  String get signalRHubUrl {
    final u = Uri.parse(client.options.baseUrl);
    final origin = u.hasPort ? '${u.scheme}://${u.host}:${u.port}' : '${u.scheme}://${u.host}';
    return '$origin/hubs/appointments';
  }
}
