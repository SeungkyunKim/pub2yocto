import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:yaml/yaml.dart';

class PubEntry {
  final String _name;
  final String _dependency;
  final PubDesc? _description;
  final String _source;
  final String _version;

  late String? _resolvedUrl;

  String get name => _name;
  String get dep => _dependency;

  bool get hosted => _source == 'hosted';
  bool get git => _source == 'git';
  bool get remote => git || hosted;

  String get version => _version;
  String? get sha256 => _description?.sha256;
  String? get ref => _description?.ref;

  String? get url {
    if (hosted) {
      return _resolvedUrl;
    } else if (git) {
      return _description?.url;
    }
    return null;
  }

  String? get host {
    final RegExp regExp = RegExp(r'^https?://');
    String? hostName = _description?.url?.replaceFirst(regExp, '');
    if (hostName == null) return hostName;

    hostName = Uri.encodeComponent(hostName);
    return hostName.replaceAll('%2F', '%47');
  }

  PubEntry({
    required String name,
    required String dependency,
    required PubDesc? description,
    required String source,
    required String version,
  })  : _name = name,
        _dependency = dependency,
        _description = description,
        _source = source,
        _version = version;

  // Factory constructor to create an instance from a YamlMap
  factory PubEntry.fromYamlMap(String name, YamlMap map) {
    if (map['dependency'] is! String ||
        map['source'] is! String ||
        map['version'] is! String) {
      throw ArgumentError('Invalid types in YamlMap');
    }
    if (!map.containsKey('dependency') ||
        !map.containsKey('source') ||
        !map.containsKey('version') ||
        !map.containsKey('description')) {
      throw ArgumentError('Missing required keys in YamlMap');
    }

    PubDesc? desc;
    if (map['description'] is YamlMap) {
      desc = PubDesc.fromYamlMap(map['description'] as YamlMap);
    }

    return PubEntry(
      name: name,
      dependency: map['dependency'] as String,
      description: desc,
      source: map['source'] as String,
      version: map['version'] as String,
    );
  }

  Future<void> resolveUrl() async {
    String? hostedUrl = _description?.url;
    final String pkgName = _name;

    if (!hosted) {
      print('  Skipping non-hosted pkg: $pkgName');
      return;
    }

    if (hostedUrl == null) {
      _resolvedUrl = null;
      return;
    }

    // ex: https://pub.dev/api/packages/plugin_platform_interface
    hostedUrl = hostedUrl.endsWith('/')
        ? hostedUrl.substring(0, hostedUrl.length - 1)
        : hostedUrl;
    final requestUrl = '$hostedUrl/api/packages/$pkgName';
    final url = Uri.parse(requestUrl);

    try {
      final response = await http.get(url);

      if (response.statusCode != 200) {
        throw HttpException('HTTP error: ${response.statusCode}');
      }

      final pubPackageJson = json.decode(response.body) as Map<String, dynamic>;

      for (var verPkg in pubPackageJson['versions'] as List<dynamic>) {
        final versionData = verPkg as Map<String, dynamic>;

        if (versionData['version'] == _version) {
          _resolvedUrl = versionData['archive_url'] as String;
          break;
        }
      }
    } catch (e) {
      print("Error fetching package[$pkgName] data: $e");
    }
  }

  @override
  String toString() {
    return 'PubEntry{name: $_name, '
        'description: $_description, version: $_version}';
  }

  String uri() {
    String? uri;

    if (hosted) {
      uri = 'SRC_URI:append = " ${url};name=${_name};'
          'subdir=\${PUB_CACHE_LOCAL}/hosted/${host}/${_name}-${_version}"';
    } else if (git) {
      uri = 'SRC_URI:append = " git:://${url};name=${_name};protocol=ssh;'
          'destsuffix=\${PUB_CACHE_LOCAL}/git/${_name}-${ref};nobranch=1"';
    }
    return uri ?? '';
  }

  String checksum() {
    String? checksum;

    if (hosted) {
      checksum = 'SRC_URI[${_name}.sha256sum] = "$sha256"';
    } else if (git) {
      checksum = 'SRCREV_${_name} = "$ref"';
    }
    return checksum ?? '';
  }
}

class PubDesc {
  final String? _name;
  final String? _sha256;
  final String? _resolved_ref;
  final String? _url;

  String? get name => _name;
  String? get url => _url;
  String? get sha256 => _sha256;
  String? get ref => _resolved_ref;

  PubDesc(
      {required String? name,
      required String? sha256,
      required String? resolved_ref,
      String? url})
      : _name = name,
        _sha256 = sha256,
        _resolved_ref = resolved_ref,
        _url = url;

  // Factory constructor to create an instance from a YamlMap
  factory PubDesc.fromYamlMap(YamlMap map) {
    return PubDesc(
      name: map['name'] ?? null as String?,
      sha256: map['sha256'] ?? null as String?,
      resolved_ref: map['resolved-ref'] ?? null as String?,
      url: map['url'] ?? null as String?,
    );
  }

  @override
  String toString() {
    return 'PubDesc{sha256: $sha256, ref: $ref, url: $url}';
  }
}
