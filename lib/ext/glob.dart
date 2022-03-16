import 'dart:core';
import 'package:file/file.dart';
import 'package:glob/glob.dart';
import 'package:chest/ext/path.dart';
import 'package:chest/ext/string.dart';

extension GlobExt on Glob {

  //////////////////////////////////////////////////////////////////////////////

  static const String all = '*';

  static final RegExp _rexRecursive = RegExp(r'\*\*|[\*\?].*[\/\\]', caseSensitive: false);

  //////////////////////////////////////////////////////////////////////////////

  static bool isRecursive(String? pattern) =>
    ((pattern != null) && _rexRecursive.hasMatch(pattern));

  //////////////////////////////////////////////////////////////////////////////

  static bool isGlobPattern(String? pattern) {
    if (pattern == null) {
      return false;
    }

    if (pattern.contains('*') ||
        pattern.contains('?') ||
        pattern.contains('{') ||
        pattern.contains('[')) {
      return true;
    }

    return false;
  }

  //////////////////////////////////////////////////////////////////////////////

  static List<String> splitPattern(String pattern) {
    var dirName = '';

    if (pattern.isEmpty || !pattern.contains(Path.separator)) {
      if (Path.driveSeparator.isEmpty || !pattern.contains(Path.driveSeparator)) {
        return [dirName, pattern];
      }
    }

    var parts = Path.dirname(pattern).split(Path.separator);

    for (var part in parts) {
      if (isGlobPattern(part)) {
        break;
      }
      if (part.isEmpty) {
        dirName += Path.separator;
      }
      else {
        dirName = Path.join(dirName, part);
      }
    }

    return [dirName, Path.relative(pattern, from: dirName)];
  }

  //////////////////////////////////////////////////////////////////////////////

  static Glob toGlob(String? pattern, {bool? isPath, FileSystem? fileSystem}) {
    var patternEx = ((pattern == null) || pattern.isBlank() ? all : pattern);

    var filter = Glob(
      Path.toPosix(patternEx),
      context: Path.fileSystem.path,
      recursive: isRecursive(patternEx),
      caseSensitive: Path.isCaseSensitive
    );

    return filter;
  }

  //////////////////////////////////////////////////////////////////////////////

}
