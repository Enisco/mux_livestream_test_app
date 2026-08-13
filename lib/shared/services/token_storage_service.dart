import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorageService {
  static const _accessTokenKey = 'gtube_access_token';
  static const _refreshTokenKey = 'gtube_refresh_token';
  static const _sessionIdKey = 'gtube_session_id';

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<String?> get accessToken => _storage.read(key: _accessTokenKey);
  Future<String?> get refreshToken => _storage.read(key: _refreshTokenKey);
  Future<String?> get sessionId => _storage.read(key: _sessionIdKey);

  Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
    String? sessionId,
  }) => Future.wait<void>([
    _storage.write(key: _accessTokenKey, value: accessToken),
    _storage.write(key: _refreshTokenKey, value: refreshToken),
    if (sessionId != null) _storage.write(key: _sessionIdKey, value: sessionId),
  ]);

  Future<void> clearAll() => Future.wait<void>([
    _storage.delete(key: _accessTokenKey),
    _storage.delete(key: _refreshTokenKey),
    _storage.delete(key: _sessionIdKey),
  ]);

  Future<bool> get hasSession async {
    final token = await refreshToken;
    return token != null && token.isNotEmpty;
  }
}
