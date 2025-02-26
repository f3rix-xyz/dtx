
// File: utils/env_config.dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvConfig {
  static String get apiBaseUrl => 
    dotenv.get('API_BASE_URL', fallback: 'http://10.61.67.128:8080');
}
