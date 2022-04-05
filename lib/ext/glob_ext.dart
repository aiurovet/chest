// Copyright (c) 2022, Alexander Iurovetski
// All rights reserved under MIT license (see LICENSE file)

import 'dart:core';
import 'package:file/file.dart';
import 'package:glob/glob.dart';

import 'package:chest/ext/path_ext.dart';

extension GlobExt on Glob {
  /// A pattern to locate glob patterns
  ///
  static final _isGlobPatternRegex =
      RegExp(r'[\*\?\{\[]', caseSensitive: false);

  /// A pattern to locate a combination of glob characters which means recursive directory scan
  ///
  static final _isRecursiveGlobPatternRegex =
      RegExp(r'\*\*|[\*\?].*[\/\\]', caseSensitive: false);

  /// Convert [pattern] string to a proper glob object considering the file system [fs]
  ///
  static Glob fromFileSystemPattern(String? pattern, FileSystem fs) {
    var patternEx = ((pattern == null) || pattern.isEmpty ? '*' : pattern);

    var filter = Glob(fs.path.adjust(patternEx),
        context: fs.path,
        recursive: isRecursiveGlobPattern(patternEx),
        caseSensitive: fs.path.isCaseSensitive);

    return filter;
  }

  /// Check whether [pattern] indicates recursive directory scan
  ///
  static bool isRecursiveGlobPattern(String? pattern) =>
      (pattern != null) && _isRecursiveGlobPatternRegex.hasMatch(pattern);

  /// Check whether [pattern] contains spoecial glob pattern characters
  ///
  static bool isGlobPattern(String? pattern) =>
      (pattern != null) && _isGlobPatternRegex.hasMatch(pattern);

  /// Split [this].pattern in to a plan directory and a glob sub-path like:
  /// 'ab/cd*/efgh/\*\*.ijk' => 'ab', 'cd*/efgh/**.ijk'
  ///
  List<String> split(FileSystem fs) {
    if (pattern.isEmpty || !pattern.contains(fs.path.separator)) {
      return ['', pattern];
    }

    var globPos = _isGlobPatternRegex.firstMatch(pattern)?.start ?? -1;
    var subPat = (globPos < 0 ? pattern : pattern.substring(0, globPos));
    var lastSepPos = subPat.lastIndexOf(fs.path.separator);

    if (lastSepPos < 0) {
      return ['', pattern];
    }

    return [
      pattern.substring(0, lastSepPos),
      pattern.substring(lastSepPos + 1),
    ];
  }
}
