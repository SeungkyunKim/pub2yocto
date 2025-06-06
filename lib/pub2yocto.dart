import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:yaml/yaml.dart';
import 'package:pub2yocto/pub_entry.dart';

class PubspecLockParser {
  final File inputFile;
  final File outputFile;
  final String? downloadPrefix;
  final List<PubEntry> pubEntries = [];

  PubspecLockParser(inputFilePath, String outputFilePath, {this.downloadPrefix})
      : inputFile = File(inputFilePath),
        outputFile = File(outputFilePath);

  Future<void> parse() async {
    if (!inputFile.existsSync()) {
      print('File not found: ${inputFile.path}');
      return;
    }

    final content = inputFile.readAsStringSync();
    final yamlMap = loadYaml(content);

    for (var pkg in yamlMap['packages'].entries) {
      print('Parsing package: ${pkg.key}');
      PubEntry entry = PubEntry.fromYamlMap(pkg.key, pkg.value as YamlMap);

      try {
        await entry.resolveUrl();
        pubEntries.add(entry);
      } catch (e) {
        print('Error resolving URL: $e');
      }
    }
  }

  Future<void> writeAsRecipe() async {
    try {
      await outputFile.writeAsString(
        '# Do not edit. This file is generated by pub2yocto.\n'
        '# "PUB_CACHE_LOCAL is a relative path starting from \${WORK_DIR} that specifies the pub_cache \n'
        '# path used in each individual recipe. The default path is \${WORK_DIR}/pub_cache."\n\n'
      );

      await outputFile.writeAsString(
        'PUB_CACHE_LOCAL ?= "pub_cache"\n'
        'PUBSPEC_LOCK_SHA256 = "${await getLockSHA256()}"\n\n',
        mode: FileMode.append,
      );
    } catch (e) {
      print('An error occurred while resetting the file: $e');
    }

    for (var entry in pubEntries) {
      if (entry.remote) {
        try {
          await outputFile.writeAsString(
              '${entry.uri(downloadPrefix: downloadPrefix)}\n',
              mode: FileMode.append);
          await outputFile.writeAsString('${entry.checksum()}\n',
              mode: FileMode.append);
          if (entry.git) {
            await outputFile.writeAsString(
                'SRCREV_FORMAT:append = " ${entry.name}"\n',
                mode: FileMode.append);
          }
        } catch (e) {
          print('An error occurred while writing to the file: $e');
        }
      }
    }
  }

  Future<String> getLockSHA256() async {
    try {
      if (!inputFile.existsSync()) {
        throw Exception('File not found: ${inputFile.path}');
      }

      final bytes = await inputFile.readAsBytes();
      final checksum = sha256.convert(bytes).toString();
      return checksum;
    } catch (e) {
      print('An error occurred while calculating the checksum: $e');
      rethrow;
    }
  }
}
