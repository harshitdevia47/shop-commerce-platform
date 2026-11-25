// Makes config/firebase.json (build defines) from platform_app/google-services.json:
//   dart run tool/firebase_defines.dart
// Then build with --dart-define-from-file=config/firebase.json as well. Both files stay out of git.
import 'dart:convert';
import 'dart:io';

const package = 'in.qcommerce.platformadmin';

void main() {
  final file = File('google-services.json');
  if (!file.existsSync()) {
    stderr.writeln('google-services.json not found in platform_app/ (Firebase console → add Android app $package)');
    exit(1);
  }
  final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final project = json['project_info'] as Map<String, dynamic>;
  final entry = (json['client'] as List<dynamic>).cast<Map<String, dynamic>>().where((c) {
    final info = (c['client_info'] as Map<String, dynamic>)['android_client_info'] as Map<String, dynamic>;
    return info['package_name'] == package;
  }).firstOrNull;
  if (entry == null) {
    stderr.writeln('google-services.json has no Android app $package');
    exit(1);
  }
  final keys = (entry['api_key'] as List<dynamic>).cast<Map<String, dynamic>>();
  final defines = {
    'FIREBASE_API_KEY': keys.first['current_key'] as String,
    'FIREBASE_APP_ID': (entry['client_info'] as Map<String, dynamic>)['mobilesdk_app_id'] as String,
    'FIREBASE_SENDER_ID': project['project_number'] as String,
    'FIREBASE_PROJECT_ID': project['project_id'] as String,
  };
  File('config/firebase.json').writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(defines)}\n');
  stdout.writeln('Wrote config/firebase.json');
}
