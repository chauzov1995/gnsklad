import 'gn_api_key.local.dart';

const String apiUrl = 'https://ecad.giulianovars.ru/gn_api.php';

// TEMPORARY: local, git-ignored key supports ordinary Android Studio builds.
// Replace this production-key delivery mechanism after today's deployment.
const String apiKey = String.fromEnvironment(
  'GN_API_KEY',
  defaultValue: productionGnApiKey,
);
