import 'package:path/path.dart' as p;

/// A helper extension for path API
///
extension PathExt on p.Context {
  /// Directory separator - POSIX
  ///
  static const separatorPosix = r'/';

  /// Escaped directory separator - POSIX
  ///
  static const separatorPosixEscaped = r'\/';

  /// Directory separator - Windows
  ///
  static const separatorWindows = r'\';

  /// Escaped directory separator - Windows
  ///
  static const separatorWindowsEscaped = r'\\';

  /// Fix [aPath] by replacing every Posix or Windows separator with the current one
  ///
  String adjust(String? aPath) {
    if ((aPath == null) || aPath.isEmpty) {
      return '';
    }

    if (separator == separatorPosix) {
      return aPath.replaceAll(separatorWindows, separator);
    } else {
      return aPath.replaceAll(separatorPosix, separator);
    }
  }

  /// Canonicalize [aPath] and keep case for Windows
  ///
  String getFullPath(String? aPath) {
    var full = canonicalize(adjust(aPath));

    if (isCaseSensitive || (aPath == null) || aPath.isEmpty) {
      return full;
    }

    // Path canonicalization on Windows converts the original path to lower case, so
    // trying to keep the original parts of path as much as possible (at least, the basename)
    //
    var partsOfFull = full.toLowerCase().split(separator);
    var partsOfPath = aPath.split(separator);

    var cntFull = partsOfFull.length - 1;
    var cntPath = partsOfPath.length - 1;

    var isChanged = false;

    for (var curFull = cntFull, curPath = cntPath;
        (curFull >= 0) && (curPath >= 0);
        curFull--, curPath--) {
      var partOfFull = partsOfFull[curFull];
      var partOfPath = partsOfPath[curPath];

      if (partOfFull.length != partOfPath.length) {
        break;
      }

      if (partOfFull != partOfPath.toLowerCase()) {
        break;
      }

      isChanged = true;
      partsOfFull[curFull] = partOfPath;
    }

    return (isChanged ? partsOfFull.join(separator) : full);
  }

  /// Check whether the file system is case-sensitive
  ///
  bool get isCaseSensitive => (separator == separatorPosix);

  /// Check whether [aPath] represents a hidden file or directory
  /// (i.e. [aPath] contains a sub-dir or filename starting with a dot)
  /// Ideally, [aPath] should be a full path to avoid possible side
  /// effects from . and ..
  ///
  bool isHidden(String aPath) =>
    (aPath.contains(separator + '.') || (aPath[0] == '.'));

  /// Check whether the file system is POSIX-compliant
  ///
  bool get isPosix => (separator == separatorPosix);

  /// Convert all separators in [aPath] to the POSIX ones
  ///
  String toPosix(String? aPath, {bool isEscaped = false}) {
    if (aPath == null) {
      return '';
    }

    if (aPath.isEmpty || (separator == separatorPosix)) {
      return aPath;
    }

    if (isEscaped) {
      return aPath.replaceAll(separatorWindowsEscaped, separatorPosixEscaped);
    } else {
      return aPath.replaceAll(separatorWindows, separatorPosix);
    }
  }
}
