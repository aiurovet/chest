// Copyright (c) 2022, Alexander Iurovetski
// All rights reserved under MIT license (see LICENSE file)

import 'dart:core';
import 'package:file/file.dart';
import 'package:glob/glob.dart';

import 'package:chest/ext/path_ext.dart';

extension GlobExt on Glob {
  /// A pattern to list any file system element
  ///
  static final _anyPattern = r'*';

  /// A separator between the drive name and the rest of the path
  ///
  static final _driveSeparator = r':';

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
  static Glob fromFileSystemPattern(FileSystem fs, String? pattern) {
    var patternEx = ((pattern == null) || pattern.isEmpty ? _anyPattern : pattern);

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
  static List<String> list(FileSystem fs, {String? pattern, bool followLinks = true}) {
    var rootAndPattern = toRootAndPattern(fs, pattern);

    var glob = fromFileSystemPattern(fs, rootAndPattern[1]);
    glob.listFileSystem(fs, root: rootAndPattern[0], followLinks: followLinks);

    return [];
  }

  /// Split [this].pattern in to a plan directory and a glob sub-path like:
  /// 'ab/cd*/efgh/\*\*.ijk' => 'ab', 'cd*/efgh/**.ijk'
  ///
  static List<String> toRootAndPattern(FileSystem fs, String? pattern) {
    if ((pattern == null) || pattern.isEmpty) {
      return ['', _anyPattern];
    }

    var patternEx = fs.path.adjust(pattern);

    if (!patternEx.contains(fs.path.separator)) {
      return ['', patternEx];
    }

    var globPos = _isGlobPatternRegex.firstMatch(patternEx)?.start ?? -1;
    var subPat = (globPos < 0 ? patternEx : patternEx.substring(0, globPos));
    var lastSepPos = subPat.lastIndexOf(fs.path.separator);

    if (lastSepPos < 0) {
      return ['', patternEx];
    }

    var extraLen = ((lastSepPos == 0) || (patternEx[lastSepPos - 1] == _driveSeparator) ? 1 : 0);

    var root = patternEx.substring(0, lastSepPos + extraLen);
    subPat = patternEx.substring(lastSepPos + 1);

    if (subPat.isEmpty) {
      subPat = _anyPattern;
    }

    return [root, subPat];
  }
}
