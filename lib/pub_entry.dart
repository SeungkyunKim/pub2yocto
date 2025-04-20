import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:yaml/yaml.dart';

/// Base class for a pub package entry.
/// It holds the common data and helper methods.
class PubEntry {
  final String _name;
  final String _dependency;
  final PubDesc? _description;
  final String _source;
  final String _version;

  // Common constructor is internal – use the factory to get the proper type.
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

  /// Factory constructor that creates a Hosted or Git version if needed;
  /// for other sources it creates a generic PubEntry.
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

    String source = map['source'] as String;
    if (source == 'hosted') {
      return HostedPubEntry.fromYamlMap(name, map);
    } else if (source == 'git') {
      return GitPubEntry.fromYamlMap(name, map);
    } else {
      // For other types, just return the base class instance
      PubDesc? desc;
      if (map['description'] is YamlMap) {
        desc = PubDesc.fromYamlMap(map['description'] as YamlMap);
      }
      return PubEntry(
        name: name,
        dependency: map['dependency'] as String,
        description: desc,
        source: source,
        version: map['version'] as String,
      );
    }
  }

  // Getter methods for accessing fields.
  String get name => _name;
  String get dep => _dependency;
  String get version => _version;
  PubDesc? get description => _description;
  bool get hosted => _source == 'hosted';
  bool get git => _source == 'git';
  bool get remote => hosted || git;

  Map<String?, String?> splitUri() {
    String? uri = _description?.url;
    if (uri == null) return {'protocol': null, 'address': null};

    // Regular expression to match the protocol
    RegExp regExp = RegExp(r'^(.*?):\/\/');
    String? protocol;
    String address = uri;

    if (regExp.hasMatch(uri)) {
      protocol = regExp.firstMatch(uri)?.group(1);
      address = uri.replaceFirst(regExp, '');
    }
    return {'protocol': protocol, 'address': address};
  }

  /// Returns an encoded version of the host portion of the URL.
  /// (Replaces '/' with '%47' after encoding.)
  String? get encodedHost {
    String? hostName = splitUri()['address'];
    if (hostName == null) return null;
    hostName = Uri.encodeComponent(hostName);
    return hostName.replaceAll('%2F', '%47');
  }

  /// By default, a generic PubEntry does not fetch a resolved URL.
  Future resolveUrl() async {
    // Do nothing for non-remote types (or types that do not override this)
    print(' Skipping non-remote type: $name');
  }

  String uri({String? downloadPrefix}) {
    return '';
  }

  String checksum() {
    return '';
  }

  @override
  String toString() {
    return 'PubEntry{name: $_name, description: $_description, version: $_version}';
  }
}

/// HostedPubEntry is a subtype of PubEntry for hosted packages.
/// It overrides resolveUrl to perform an HTTP call and produces
/// a SRC_URI and checksum line for hosted packages.
class HostedPubEntry extends PubEntry {
  String? _resolvedUrl;
  HostedPubEntry({
    required super.name,
    required super.dependency,
    required super.description,
    required super.version,
  }) : super(source: 'hosted');
  factory HostedPubEntry.fromYamlMap(String name, YamlMap map) {
    PubDesc? desc;
    if (map['description'] is YamlMap) {
      desc = PubDesc.fromYamlMap(map['description'] as YamlMap);
    }
    return HostedPubEntry(
      name: name,
      dependency: map['dependency'] as String,
      description: desc,
      version: map['version'] as String,
    );
  }
  @override
  Future resolveUrl() async {
    String? hostedUrl = description?.url;
    final String pkgName = name;

    if (hostedUrl == null) {
      _resolvedUrl = null;
      return;
    }

    // Remove any trailing slash
    hostedUrl = hostedUrl.endsWith('/')
        ? hostedUrl.substring(0, hostedUrl.length - 1)
        : hostedUrl;
    final requestUrl = '$hostedUrl/api/packages/$pkgName';
    final urlParsed = Uri.parse(requestUrl);

    try {
      final response = await http.get(urlParsed);
      if (response.statusCode != 200) {
        throw HttpException('HTTP error: ${response.statusCode}');
      }

      final pubPackageJson = json.decode(response.body) as Map<String, dynamic>;
      for (var verPkg in pubPackageJson['versions'] as List<dynamic>) {
        final versionData = verPkg as Map<String, dynamic>;
        if (versionData['version'] == version) {
          _resolvedUrl = versionData['archive_url'] as String;
          break;
        }
      }
    } catch (e) {
      print("Error fetching package[$pkgName] data: $e");
    }
  }

  /// Resolves and returns the file name from the `_resolvedUrl` if available.
  ///
  /// This method parses the `_resolvedUrl` as a URI and extracts the last segment
  /// of the path as the file name. If the file name starts with `_name`, it appends
  /// the file name to `_name` with a hyphen (`-`) separator and returns the result.
  String? resolvedFileName() {
    if (_resolvedUrl == null) return null;

    final uri = Uri.parse(_resolvedUrl!);
    final pathSegments = uri.pathSegments;

    if (pathSegments.isEmpty) return null;

    String fileName = pathSegments.last;
    if (!fileName.startsWith(_name)) {
      return '$_name-$fileName';
    }

    return fileName;
  }

  // For hosted packages the effective url is the resolved url (if any) or the original url.
  String? get url => _resolvedUrl ?? description?.url;
  @override
  String uri({String? downloadPrefix}) {
    final String? fileName = resolvedFileName();
    String prefix = (downloadPrefix != null && !downloadPrefix.endsWith('/'))
        ? '$downloadPrefix/'
        : (downloadPrefix ?? 'pub/');
    String downloadOpt =
        (fileName == null) ? '' : ';downloadfilename=$prefix$fileName';

    return 'SRC_URI:append = " $url;name=$name;subdir=\${PUB_CACHE_LOCAL}/hosted/$encodedHost/$name-$version$downloadOpt"';
  }

  @override
  String checksum() {
    return 'SRC_URI[$name.sha256sum] = "${description?.sha256}"';
  }
}

/// GitPubEntry is a subtype of PubEntry for git packages.
/// It returns a SRC_URI and checksum line suitable for git repositories.
class GitPubEntry extends PubEntry {
  GitPubEntry({
    required super.name,
    required super.dependency,
    required super.description,
    required super.version,
  }) : super(source: 'git');
  factory GitPubEntry.fromYamlMap(String name, YamlMap map) {
    PubDesc? desc;
    if (map['description'] is YamlMap) {
      desc = PubDesc.fromYamlMap(map['description'] as YamlMap);
    }
    return GitPubEntry(
      name: name,
      dependency: map['dependency'] as String,
      description: desc,
      version: map['version'] as String,
    );
  }

  @override
  String uri({String? downloadPrefix}) {
    // Use splitUri() from the base to extract protocol and address.
    final split = splitUri();
    final address = split['address'] ?? '';
    // Default to ssh if not provided
    final gitProtocol = split['protocol'] ?? 'ssh';

    return 'SRC_URI:append = " git://$address;name=$name;protocol=$gitProtocol;'
        'destsuffix=\${PUB_CACHE_LOCAL}/git/$name-${description?.ref};nobranch=1"';
  }

  @override
  String checksum() {
    return 'SRCREV_$name = "${description?.ref}"';
  }
}

/// A simple description class holding extra package data.
class PubDesc {
  final String? _name;
  final String? _sha256;
  final String? _resolvedRef;
  final String? _url;
  PubDesc({
    required String? name,
    required String? sha256,
    required String? resolvedRef,
    String? url,
  })  : _name = name,
        _sha256 = sha256,
        _resolvedRef = resolvedRef,
        _url = url;
  String? get name => _name;
  String? get url => _url;
  String? get sha256 => _sha256;
  String? get ref => _resolvedRef;

  /// Create a PubDesc from a YamlMap.
  factory PubDesc.fromYamlMap(YamlMap map) {
    return PubDesc(
      name: map['name'] as String?,
      sha256: map['sha256'] as String?,
      resolvedRef: map['resolved-ref'] as String?,
      url: map['url'] as String?,
    );
  }
  @override
  String toString() {
    return 'PubDesc{sha256: $sha256, ref: $ref, url: $url}';
  }
}
