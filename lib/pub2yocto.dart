import 'dart:io';
import 'package:yaml/yaml.dart';
import 'package:pub2yocto/pub_entry.dart';

class PubspecLockParser {
  final String filePath;
  final File outputFile;
  final List<PubEntry> pubEntries = [];

  PubspecLockParser(this.filePath, String outputFilePath)
      : outputFile = File(outputFilePath);

  Future<void> parse() async {
    final file = File(filePath);
    if (!file.existsSync()) {
      print('File not found: $filePath');
      return;
    }

    final content = file.readAsStringSync();
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
          '# Do not edit. This file is generated by pub2yocto.\n');
      await outputFile.writeAsString(
        '# "PUB_CACHE_LOCAL is a relative path starting from \${WORK_DIR} that specifies the pub_cache \n'
        '# path used in each individual recipe. The default path is \${WORK_DIR}/pub_cache."\n'
        'PUB_CACHE_LOCAL ?= "pub_cache"\n\n',
        mode: FileMode.append,
      );
      print('File content has been reset: $outputFile');
    } catch (e) {
      print('An error occurred while resetting the file: $e');
    }

    for (var entry in pubEntries) {
      if (entry.remote) {
        try {
          await outputFile.writeAsString(entry.uri() + '\n',
              mode: FileMode.append);
          await outputFile.writeAsString(entry.checksum() + '\n',
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
}
