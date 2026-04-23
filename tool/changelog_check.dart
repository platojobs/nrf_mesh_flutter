import 'dart:io';

class SemVer implements Comparable<SemVer> {
  final int major;
  final int minor;
  final int patch;

  const SemVer(this.major, this.minor, this.patch);

  static SemVer parse(String s) {
    final m = RegExp(r'^(\d+)\.(\d+)\.(\d+)$').firstMatch(s.trim());
    if (m == null) {
      throw FormatException('Invalid semver: $s');
    }
    return SemVer(
      int.parse(m.group(1)!),
      int.parse(m.group(2)!),
      int.parse(m.group(3)!),
    );
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
  final changelog = File('CHANGELOG.md');

  if (!pubspec.existsSync()) {
    stderr.writeln('ERROR: pubspec.yaml not found.');
    exit(1);
  }
  if (!changelog.existsSync()) {
    stderr.writeln('ERROR: CHANGELOG.md not found.');
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
  final pubspecVersionStr = pubspecVersionMatch.group(1)!;
  final pubspecVersion = SemVer.parse(pubspecVersionStr);

  final changelogText = changelog.readAsStringSync();
  final versions = <SemVer>[];
  final versionLines = <String>[];
  for (final m in RegExp(r'^\s*##\s+([0-9]+\.[0-9]+\.[0-9]+)\s*$',
          multiLine: true)
      .allMatches(changelogText)) {
    final v = m.group(1)!;
    versionLines.add(v);
    versions.add(SemVer.parse(v));
  }

  if (versions.isEmpty) {
    stderr.writeln('ERROR: No versions found in CHANGELOG.md (expected `## x.y.z`).');
    exit(1);
  }

  // 1) Top changelog version must match pubspec version.
  final top = versions.first;
  if (top.compareTo(pubspecVersion) != 0) {
    stderr.writeln(
      'ERROR: CHANGELOG top version ($top) does not match pubspec.yaml ($pubspecVersion).',
    );
    exit(1);
  }

  // 2) Versions must be strictly non-increasing (latest first).
  for (var i = 0; i < versions.length - 1; i++) {
    final a = versions[i];
    final b = versions[i + 1];
    if (a.compareTo(b) < 0) {
      stderr.writeln('ERROR: CHANGELOG is not sorted (latest first).');
      stderr.writeln('  Found ${versionLines[i]} above ${versionLines[i + 1]}.');
      exit(1);
    }
  }

  stdout.writeln('OK: changelog ordering and version match verified.');
}

