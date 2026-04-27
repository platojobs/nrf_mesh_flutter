import 'dart:io';

class SemVer implements Comparable<SemVer> {
  final int major;
  final int minor;
  final int patch;

  const SemVer(this.major, this.minor, this.patch);

  static SemVer parse(String s) {
    final m = RegExp(r'^(\d+)\.(\d+)\.(\d+)$').firstMatch(s.trim());
    if (m == null) throw FormatException('Invalid semver: $s');
    return SemVer(int.parse(m.group(1)!), int.parse(m.group(2)!), int.parse(m.group(3)!));
  }

  @override
  int compareTo(SemVer other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    return patch.compareTo(other.patch);
  }

  @override
  String toString() => '$major.$minor.$patch';
}

void main() {
  final pubspec = File('pubspec.yaml');
  final readme = File('README.md');

  if (!pubspec.existsSync()) {
    stderr.writeln('ERROR: pubspec.yaml not found.');
    exit(1);
  }
  if (!readme.existsSync()) {
    stderr.writeln('ERROR: README.md not found.');
    exit(1);
  }

  final pubspecText = pubspec.readAsStringSync();
  final pubspecVersionMatch =
      RegExp(r'^\s*version:\s*([0-9]+\.[0-9]+\.[0-9]+)\s*$', multiLine: true)
          .firstMatch(pubspecText);
  if (pubspecVersionMatch == null) {
    stderr.writeln('ERROR: Could not find `version:` in pubspec.yaml.');
    exit(1);
  }
  final pubspecVersion = SemVer.parse(pubspecVersionMatch.group(1)!);

  final readmeText = readme.readAsStringSync();
  final readmeDepMatch = RegExp(
    r'^\s*nrf_mesh_flutter:\s*\^([0-9]+\.[0-9]+\.[0-9]+)\s*$',
    multiLine: true,
  ).firstMatch(readmeText);

  if (readmeDepMatch == null) {
    stderr.writeln('ERROR: Could not find `nrf_mesh_flutter: ^x.y.z` in README.md.');
    exit(1);
  }

  final readmeVersion = SemVer.parse(readmeDepMatch.group(1)!);

  if (readmeVersion.compareTo(pubspecVersion) != 0) {
    stderr.writeln(
      'ERROR: README install snippet (^$readmeVersion) does not match pubspec.yaml ($pubspecVersion).',
    );
    exit(1);
  }

  stdout.writeln('OK: README install snippet matches pubspec version.');
}

