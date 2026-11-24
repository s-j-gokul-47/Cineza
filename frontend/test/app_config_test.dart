import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/config/app_config.dart';
import 'package:frontend/services/api_service.dart';

void main() {
  test('AppConfig exposes defaults and ApiService uses AppConfig.apiBaseUrl', () {
    expect(AppConfig.apiBaseUrl, isNotEmpty);
    expect(ApiService.baseUrl, AppConfig.apiBaseUrl);
    expect(AppConfig.authOtpUrl, isNotEmpty);
    expect(AppConfig.termsPolicyUrl, '${AppConfig.publicWebUrl}/terms-policy');
    expect(AppConfig.trailerEmbedBaseUrl, isNotEmpty);
    expect(AppConfig.placeholderImageBaseUrl, isNotEmpty);
    expect(AppConfig.defaultPosterUrl, isNotEmpty);
  });
}
