import 'dart:io';
import 'package:args/args.dart';
import 'package:yaml/yaml.dart';
import 'package:pub2yocto/pub2yocto.dart';

void main(List<String> arguments) async {
  // Define the parser and options
  final parser = ArgParser()
    ..addOption(
      'input',
      abbr: 'i',
      help: 'Input file name',
      defaultsTo: 'pubspec.lock',
    )
    ..addOption('output', abbr: 'o', help: 'Output file name')
    ..addOption(
      'download-prefix',
      abbr: 'd',
      help: 'Download directory prefix for hosted type',
    )
    ..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Show usage information',
    );

  // Parse the arguments
  ArgResults argResults;
  try {
    argResults = parser.parse(arguments);
  } catch (e) {
    print('Error: ${e.toString()}');
    print('Usage: dart script.dart -i <input_file> -o <output_file>');
    exit(1);
  }

  // Show help if requested
  if (argResults['help'] as bool) {
    print('Usage: dart script.dart <input_file> -o <output_file>');
    print(parser.usage);
    exit(0);
  }

  // Get the input and output file paths
  String? outputFilePath = argResults['output'];
  if (outputFilePath == null) {
    String? name = getPubspecName();
    outputFilePath = name != null ? '$name.inc' : 'pubspec.inc';
    print('Output file name not provided. Using default: $outputFilePath');
  }

  PubspecLockParser lockparser = PubspecLockParser(
    argResults['input'],
    outputFilePath,
    downloadPrefix: argResults['download-prefix'],
  );
  await lockparser.parse();

  await lockparser.writeAsRecipe();
}

String? getPubspecName() {
  final filePath = 'pubspec.yaml';
  final file = File(filePath);
  if (!file.existsSync()) {
    print('File not found: $filePath');
    return null;
  }

  final content = file.readAsStringSync();
  final yamlMap = loadYaml(content);

  return yamlMap['name'] as String?;
}
