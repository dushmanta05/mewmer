import 'package:flutter_dotenv/flutter_dotenv.dart';

const String _fallbackApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:3030/api/v1',
);

String get apiBaseUrl {
  if (!dotenv.isInitialized) return _fallbackApiBaseUrl;
  final value = dotenv.env['API_BASE_URL']?.trim();
  if (value == null || value.isEmpty) return _fallbackApiBaseUrl;
  return value;
}
