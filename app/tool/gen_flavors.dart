// Generates everything a client flavor needs from ../clients/<slug>/:
//   config/clients/<slug>.json            flat --dart-define-from-file values
//   assets/clients/<slug>/logo.png        flavor-only asset (pubspec `flavors:`)
//   pubspec.yaml                          generated asset block
//   flutter_launcher_icons-<slug>.yaml    launcher icon config per flavor
//   android/app/flavors.gradle            productFlavors (if android/ exists)
//   FIREBASE_* defines                    from <slug>/google-services.json, if present (push)
//
// Run from app/:  dart run tool/gen_flavors.dart
// Validate clients first with the backend CLI: (cd ../backend && npm run client -- validate)
// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

const _beginMarker = '    # BEGIN GENERATED CLIENT ASSETS (tool/gen_flavors.dart; do not edit by hand)';
const _endMarker = '    # END GENERATED CLIENT ASSETS';
final _slugPattern = RegExp(r'^[a-z][a-z0-9]*(?:_[a-z0-9]+)*$');

class Client {
  Client(this.slug, this.dir, this.json);

  final String slug;
  final Directory dir;
  final Map<String, dynamic> json;

  Map<String, dynamic> get build => json['build'] as Map<String, dynamic>;
  Map<String, dynamic> get branding => json['branding'] as Map<String, dynamic>;
  Map<String, dynamic> get locale => json['locale'] as Map<String, dynamic>;
  String get logoFile => branding['logo'] as String? ?? 'logo.png';
  String get iconFile => branding['icon'] as String? ?? 'icon.png';
  String get logoAsset => 'assets/clients/$slug/logo.png';
}

void main(List<String> args) {
  final appDir = Directory.current;
  if (!File('${appDir.path}/pubspec.yaml').existsSync()) fail('Run from the app/ directory');
  final clientsDir = Directory('${appDir.path}/../clients');
  if (!clientsDir.existsSync()) fail('clients/ directory not found at ${clientsDir.path}');

  final clients = loadClients(clientsDir);
  if (clients.isEmpty) fail('No clients found in ${clientsDir.path}');

  final defines = Directory('${appDir.path}/config/clients')..createSync(recursive: true);
  for (final client in clients) {
    writeDefines(defines, client);
    copyAssets(appDir, client);
    writeLauncherIconConfig(appDir, client);
  }
  updatePubspec(appDir, clients);
  writeAndroidFlavors(appDir, clients);

  print('Generated ${clients.length} flavor(s): ${clients.map((c) => c.slug).join(', ')}');
}

Never fail(String message) {
  stderr.writeln('gen_flavors: $message');
  exit(1);
}

List<Client> loadClients(Directory clientsDir) {
  final clients = <Client>[];
  final dirs = clientsDir.listSync().whereType<Directory>().toList()..sort((a, b) => a.path.compareTo(b.path));
  for (final dir in dirs) {
    final slug = dir.uri.pathSegments.where((s) => s.isNotEmpty).last;
    if (slug.startsWith('_') || slug.startsWith('.')) continue;
    final file = File('${dir.path}/client.json');
    if (!file.existsSync()) fail('$slug: client.json missing');
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    if (json['slug'] != slug) fail('$slug: slug in client.json must equal folder name');
    if (!_slugPattern.hasMatch(slug)) fail('$slug: invalid slug');
    clients.add(Client(slug, dir, json));
  }
  return clients;
}

void writeDefines(Directory out, Client client) {
  final colors = client.branding['colors'] as Map<String, dynamic>;
  final defines = <String, String>{
    'SHOP_KEY': client.slug,
    'APP_NAME': client.build['appName'] as String,
    'LOGO_ASSET': client.logoAsset,
    'COLOR_PRIMARY': colors['primary'] as String,
    'COLOR_SECONDARY': colors['secondary'] as String,
    'COLOR_SURFACE': colors['surface'] as String? ?? '',
    'DEFAULT_LOCALE': client.locale['default'] as String,
    'SUPPORTED_LOCALES': (client.locale['supported'] as List<dynamic>).join(','),
    ...firebaseDefines(client),
  };
  File('${out.path}/${client.slug}.json').writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(defines)}\n');
}

/// Push notifications: Firebase app values from the client's google-services.json, if present.
/// The app initializes Firebase from these defines (no google-services Gradle plugin).
Map<String, String> firebaseDefines(Client client) {
  final file = File('${client.dir.path}/google-services.json');
  if (!file.existsSync()) return {};
  final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final project = json['project_info'] as Map<String, dynamic>;
  final package = client.build['androidPackage'] as String;
  final entry = (json['client'] as List<dynamic>).cast<Map<String, dynamic>>().where((c) {
    final info = (c['client_info'] as Map<String, dynamic>)['android_client_info'] as Map<String, dynamic>;
    return info['package_name'] == package;
  }).firstOrNull;
  if (entry == null) fail('${client.slug}: google-services.json has no Android app for $package');
  final apiKeys = (entry['api_key'] as List<dynamic>).cast<Map<String, dynamic>>();
  return {
    'FIREBASE_API_KEY': apiKeys.first['current_key'] as String,
    'FIREBASE_APP_ID': (entry['client_info'] as Map<String, dynamic>)['mobilesdk_app_id'] as String,
    'FIREBASE_SENDER_ID': project['project_number'] as String,
    'FIREBASE_PROJECT_ID': project['project_id'] as String,
  };
}

void copyAssets(Directory appDir, Client client) {
  final logo = File('${client.dir.path}/${client.logoFile}');
  if (!logo.existsSync()) fail('${client.slug}: ${client.logoFile} missing');
  final target = Directory('${appDir.path}/assets/clients/${client.slug}')..createSync(recursive: true);
  logo.copySync('${target.path}/logo.png');
}

void writeLauncherIconConfig(Directory appDir, Client client) {
  final icon = File('${client.dir.path}/${client.iconFile}');
  if (!icon.existsSync()) fail('${client.slug}: ${client.iconFile} missing');
  final colors = client.branding['colors'] as Map<String, dynamic>;
  File('${appDir.path}/flutter_launcher_icons-${client.slug}.yaml').writeAsStringSync('''
# Generated by tool/gen_flavors.dart. Run: dart run flutter_launcher_icons
flutter_launcher_icons:
  android: true
  ios: false
  image_path: "../clients/${client.slug}/${client.iconFile}"
  adaptive_icon_background: "${colors['primary']}"
  adaptive_icon_foreground: "../clients/${client.slug}/${client.iconFile}"
''');
}

void updatePubspec(Directory appDir, List<Client> clients) {
  final file = File('${appDir.path}/pubspec.yaml');
  final content = file.readAsStringSync();
  final start = content.indexOf(_beginMarker);
  final end = content.indexOf(_endMarker);
  if (start < 0 || end < start) fail('pubspec.yaml is missing the generated asset markers');
  final block = StringBuffer('$_beginMarker\n');
  for (final client in clients) {
    block
      ..writeln('    - path: assets/clients/${client.slug}/')
      ..writeln('      flavors:')
      ..writeln('        - ${client.slug}');
  }
  file.writeAsStringSync(content.replaceRange(start, end, block.toString()));
}

String _groovyString(String value) => '"${value.replaceAll(r'\', r'\\').replaceAll('"', r'\"').replaceAll(r'$', r'\$')}"';

void writeAndroidFlavors(Directory appDir, List<Client> clients) {
  final androidApp = Directory('${appDir.path}/android/app');
  if (!androidApp.existsSync()) {
    print('android/ not found: run `flutter create --platforms=android --org in.qcommerce .` then re-run this tool.');
    return;
  }

  final flavors = StringBuffer();
  for (final client in clients) {
    flavors
      ..writeln('        ${client.slug} {')
      ..writeln('            dimension "client"')
      ..writeln('            applicationId ${_groovyString(client.build['androidPackage'] as String)}')
      ..writeln('            resValue "string", "app_name", ${_groovyString(client.build['appName'] as String)}')
      ..writeln('        }');

  }

  File('${androidApp.path}/flavors.gradle').writeAsStringSync('''
// Generated by tool/gen_flavors.dart from ../clients/*/client.json. Do not edit.
android {
    buildFeatures {
        resValues true
    }
    flavorDimensions "client"
    productFlavors {
$flavors    }
}
''');

  final gradleKts = File('${androidApp.path}/build.gradle.kts');
  final gradle = gradleKts.existsSync() ? gradleKts : File('${androidApp.path}/build.gradle');
  if (gradle.existsSync()) {
    final applyLine = gradle.path.endsWith('.kts') ? 'apply(from = "flavors.gradle")' : "apply from: 'flavors.gradle'";
    final text = gradle.readAsStringSync();
    if (!text.contains('flavors.gradle')) gradle.writeAsStringSync('$text\n$applyLine\n');
  }

  final manifest = File('${androidApp.path}/src/main/AndroidManifest.xml');
  if (manifest.existsSync()) {
    final text = manifest.readAsStringSync();
    final updated = text.replaceFirst(RegExp(r'android:label="[^"]*"'), 'android:label="@string/app_name"');
    if (updated != text) manifest.writeAsStringSync(updated);
  }
}
