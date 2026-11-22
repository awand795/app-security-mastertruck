class ApiConfig {
  // Gateway API Builder (Production /mastertruck/*)
  static const String gatewayBaseUrl = 'http://94.237.69.119:8081/api/data';
  static const String gatewayApiKey = 'KIM3-SECURE-TOKEN-2026-X998A7B6C';

  // Login & logout dilakukan lewat API Gateway di atas agar backend auth bisa
  // diganti/ditambah tanpa mengubah APK. Kunci API DarkoPOS disimpan di gateway.
  static const String securityLoginPath = '/mastertruck/security/login';
  static const String securityLogoutPath = '/mastertruck/security/logout';
}
