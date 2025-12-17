import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart';

final apiClientProvider = Provider((ref) => ApiClient());

class ApiClient {
  late final Dio _dio;
  final _storage = const FlutterSecureStorage();
  final String baseUrl = 'http://192.168.154.198:3000';

  ApiClient() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: 'auth_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (DioException e, handler) {
        if (e.response?.statusCode == 401) {
          // TODO: Handle token expiration (logout)
        }
        return handler.next(e);
      },
    ));
  }

  Future<String?> getToken() => _storage.read(key: 'auth_token');

  Future<void> logout() async {
    await _storage.delete(key: 'auth_token');
  }

  Future<void> login(String email, String password) async {
    final response = await _dio.post('/auth/login', data: {'email': email, 'password': password});
    final token = response.data['accessToken'];
    await _storage.write(key: 'auth_token', value: token);
  }

  Future<void> register(String email, String password) async {
    final response = await _dio.post('/auth/register', data: {'email': email, 'password': password});
    final token = response.data['accessToken'];
    await _storage.write(key: 'auth_token', value: token);
  }

  Future<void> uploadFile(
    File file, 
    String deviceId, 
    {void Function(int sent, int total)? onProgress}
  ) async {
    String fileName = basename(file.path);
    FormData formData = FormData.fromMap({
      "file": await MultipartFile.fromFile(file.path, filename: fileName),
      "deviceId": deviceId,
    });
    
    await _dio.post(
      '/files/upload', 
      data: formData,
      onSendProgress: onProgress,
    );
  }

  Future<Map<String, dynamic>> getSyncChanges(DateTime since) async {
    final response = await _dio.get('/sync/changes', queryParameters: {
      'since': since.toIso8601String(),
    });
    return response.data;
  }

  Future<void> deleteFile(String fileId) async {
    await _dio.delete('/files/$fileId');
  }
}
