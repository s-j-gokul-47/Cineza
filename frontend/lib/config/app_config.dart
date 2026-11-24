/// Centralized service discovery & endpoint configuration for Cineza.
///
/// Override any value at build or run time with `--dart-define` or
/// `--dart-define-from-file=.env` (all values retain local dev defaults).
class AppConfig {
  AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'CINEZA_API_BASE_URL',
    defaultValue: 'http://localhost:8080/api/v1',
  );

  static const String authOtpUrl = String.fromEnvironment(
    'CINEZA_AUTH_OTP_URL',
    defaultValue: 'https://cineza-auth-api.gokulakannansj.workers.dev/auth/otp',
  );

  static const String publicWebUrl = String.fromEnvironment(
    'CINEZA_PUBLIC_WEB_URL',
    defaultValue: 'https://cineza.com',
  );

  static const String termsPolicyUrl = '$publicWebUrl/terms-policy';

  static const String trailerEmbedBaseUrl = String.fromEnvironment(
    'CINEZA_TRAILER_EMBED_BASE_URL',
    defaultValue: 'https://www.youtube.com/embed',
  );

  static const String placeholderImageBaseUrl = String.fromEnvironment(
    'CINEZA_PLACEHOLDER_IMAGE_BASE_URL',
    defaultValue: 'https://via.placeholder.com',
  );

  static const String defaultPosterUrl = String.fromEnvironment(
    'CINEZA_DEFAULT_POSTER_URL',
    defaultValue:
        'https://image.tmdb.org/t/p/w500/1pdfLvkbY9ohJlCjQH2CZjjYVvJ.jpg',
  );
}
