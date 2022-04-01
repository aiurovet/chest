// Copyright (c) 2022, Alexander Iurovetski
// All rights reserved under MIT license (see LICENSE file)

import 'dart:convert';
import 'dart:io';
import 'package:chest/register_services.dart';
import 'package:chest/ext/glob_ext.dart';
import 'package:chest/ext/path_ext.dart';
import 'package:chest/options.dart';
import 'package:file/file.dart';
import 'package:glob/glob.dart';
import 'package:thin_logger/thin_logger.dart';

/// A class to scan files or stdin, filter strings and optionally, count those
///
class Scanner {
  /// The actual number of matched lines
  ///
  int count = 0;

  // Dependency injection
  //
  final _fs = services.get<FileSystem>();
  final _lineSplitter = services.get<LineSplitter>();
  final _logger = services.get<Logger>();
  final _options = services.get<Options>();

  /// The constructor
  ///
  Scanner();

  /// The execution start point
  ///
  Future exec() async {
    if (_options.isTakeFileListFromStdin) {
      await execEachFileFromStdin();
    } else if (_options.takeFileGlobList.isEmpty &&
        _options.takeFileRegexList.isEmpty) {
      execContentFromStdin();
    } else {
      await execEachFileFromList();
    }

    if (_options.isCount) {
      var isSuccess = ((count >= _options.min) &&
          ((_options.max < 0) || (count <= _options.max)));

      var isMin = (_options.max < 0);
      var isEqu = (_options.max == _options.min);

      var details = (isMin
          ? '$count (actual) >= ${_options.min} (min)'
          : isEqu
              ? '$count (actual) == ${_options.min} (expected)'
              : '${_options.min} (min) <= $count (actual) <= ${_options.max} (max)');

      _logger.out(
          '${Options.appName}: ${isSuccess ? 'succeeded' : 'failed'}: $details');
    }
  }

  /// Read content from stdin line by line, filter those and, optionally, count
  ///
  void execContentFromStdin() {
    if (_logger.isVerbose) {
      _logger.verbose('Scanning the content of stdin');
    }

    for (;;) {
      var line = stdin.readLineSync(retainNewlines: false)?.trim();

      if (line == null) {
        break;
      }

      execLine(line, '');
    }
  }

  /// Read and filter the list of files defined by options, then process each of those
  ///
  Future execEachFileFromList() async {
    var dirNameMap = <String, bool>{};

    if (_logger.isVerbose) {
      _logger.verbose('Scanning the content of files from the take-glob list');
    }

    // Collect all distinct lowest level top directory names for the further
    // pick up of all files in those directories and optionally, below
    //
    for (var takeFileGlob in _options.takeFileGlobList) {
      var dirName = takeFileGlob.split(_fs)[0];

      if (_logger.isVerbose) {
        _logger
            .verbose('Getting top directory of the take-glob "$takeFileGlob"');
      }

      if (dirName == '.') {
        dirName = '';
      }

      if (_logger.isVerbose) {
        _logger.verbose('...dir: "$dirName"');
      }

      var wasRecursive = dirNameMap[dirName];
      var isRecursive = takeFileGlob.recursive;

      if ((wasRecursive == null) || (!wasRecursive && isRecursive)) {
        if (_logger.isVerbose) {
          _logger.verbose(
              '...adding the dir with${isRecursive ? '' : 'out'} recursive scan');
        }
        dirNameMap[dirName] = isRecursive;
      }
    }

    var isAll = _options.isAll;

    // Loop through every lowest level top directory name
    //
    for (var key in dirNameMap.keys) {
      var topDirName = (
        key.isEmpty ?
        _fs.currentDirectory.path :
        _fs.path.getFullPath(key)
      );

      if (!isAll && _fs.path.isHidden(topDirName)) {
        break;
      }

      // Loop through all files in the current directory (and optionally, below)
      //
      var isRecursive = dirNameMap[key] ?? false;
      var entities = _fs.directory(topDirName).list(recursive: isRecursive);

      await for (var entity in entities) {
        var filePath = entity.path;

        if (!isAll && _fs.path.isHidden(filePath)) {
          continue;
        }

        var fileName = _fs.path.basename(filePath);

        if (_logger.isVerbose) {
          _logger.verbose('Validating the path "$filePath"');
        }

        // If not a file, get the next one
        //
        var stat = await entity.stat();

        if (stat.type != FileSystemEntityType.file) {
          if (_logger.isVerbose) {
            _logger.verbose('...not a file - skipping');
          }
          continue;
        }

        // Match the current path against take- and skip-patterns and process the file in case of success
        //
        var isValid =
            isFilePathMatchedByGlobList(
                filePath, fileName, _options.takeFileGlobList) &&
            isFilePathMatchedByRegexList(
                filePath, fileName, _options.takeFileRegexList) &&
            !isFilePathMatchedByGlobList(
                filePath, fileName, _options.skipFileGlobList) &&
            !isFilePathMatchedByRegexList(
                filePath, fileName, _options.skipFileRegexList);

        if (isValid) {
          await execFile(filePath, isCheckRequired: false);
        }
      }
    }
  }

  /// Read and filter the list of files from stdin, then process each of those
  ///
  Future execEachFileFromStdin() async {
    if (_logger.isVerbose) {
      _logger.verbose(
          'Scanning the content of files with the paths obtained from stdin');
    }

    // Loop through all file paths in stdin
    //
    for (;;) {
      var filePath = stdin.readLineSync(retainNewlines: false)?.trim();

      if (filePath == null) {
        break;
      }
      if (filePath.isEmpty) {
        continue;
      }

      var fileName = _fs.path.basename(filePath);

      if (_logger.isVerbose) {
        _logger.verbose('Validating the path "$filePath"');
      }

      // Match the current path against skip patterns and process the file in case of success
      //
      var isValid =
          !isFilePathMatchedByGlobList(
              filePath, fileName, _options.skipFileGlobList) &&
          !isFilePathMatchedByRegexList(
              filePath, fileName, _options.skipFileRegexList);

      if (isValid) {
        await execFile(filePath, isCheckRequired: true);
      }
    }
  }

  /// Check the file defined by [filePath] exists if [isCheckRequired] is set,
  /// then process that file: read it line by line, filter those which are
  /// expected and, optionally, count those, then match it aagins given range
  ///
  Future execFile(String filePath, {bool isCheckRequired = false}) async {
    if (_options.isPathsOnly) {
      if (_options.isCount) {
        ++count;
      } else {
        _logger.out(filePath);
      }
      return;
    }

    if (_logger.isVerbose) {
      _logger.verbose('Scanning the file "$filePath"');
    }

    var file = _fs.file(filePath);

    if (!isCheckRequired || await file.exists()) {
      var lines =
          file.openRead().transform(utf8.decoder).transform(_lineSplitter);

      await for (var line in lines) {
        execLine(line, filePath);
      }
    } else {
      throw Exception('File not found: "${file.path}"');
    }
  }

  /// Filter the given [line] and either print it (possibly, prefixed by [filePath]) or count
  ///
  bool execLine(String line, String filePath) {
    if (_logger.isVerbose) {
      _logger.verbose('Validating the line: $line');
    }

    var lineLC = line.toLowerCase();
    var isValid = true;

    // Matching against every plain take-text
    //
    for (var plain in _options.takeTextPlainList) {
      if (_logger.isVerbose) {
        _logger.verbose('...matching against plain take-text: $plain');
      }

      var isCaseSensitive = (plain[0] == Options.charSensitive);
      isValid = (isCaseSensitive ? line : lineLC).contains(plain.substring(1));

      if (!isValid) {
        break;
      }
    }

    if (!isValid) {
      if (_logger.isVerbose) {
        _logger.verbose('...not matched - skipping');
      }
      return false;
    }

    // Matching against every plain skip-text
    //
    for (var plain in _options.skipTextPlainList) {
      if (_logger.isVerbose) {
        _logger.verbose('...matching against plain skip-text: $plain');
      }

      var isCaseSensitive = (plain[0] == Options.charSensitive);
      isValid = !(isCaseSensitive ? line : lineLC).contains(plain.substring(1));

      if (!isValid) {
        break;
      }
    }

    if (!isValid) {
      if (_logger.isVerbose) {
        _logger.verbose('...matched - skipping');
      }
      return false;
    }

    // Matching against every take-regex
    //
    for (var regex in _options.takeTextRegexList) {
      if (_logger.isVerbose) {
        _logger.verbose('...matching against take-regex: ${regex.pattern}');
      }

      isValid = regex.hasMatch(line);

      if (!isValid) {
        break;
      }
    }

    if (!isValid) {
      if (_logger.isVerbose) {
        _logger.verbose('...not matched - skipping');
      }
      return false;
    }

    // Matching against every skip-regex
    //
    for (var regex in _options.skipTextRegexList) {
      if (_logger.isVerbose) {
        _logger.verbose('...matching against skip-regex: $regex');
      }

      isValid = !regex.hasMatch(line);

      if (!isValid) {
        break;
      }
    }

    if (!isValid) {
      if (_logger.isVerbose) {
        _logger.verbose('...matched - skipping');
      }
      return false;
    }

    if (_logger.isVerbose) {
      _logger.verbose('...matched');
    }

    if (_options.isCount) {
      ++count;
    } else {
      _logger.out(filePath.isEmpty ? line : '$filePath:$line');
    }

    return true;
  }

  /// Match [filePath] or [fileName] against every glob pattern in [globList]
  /// (stop when the first no-match encountered)
  ///
  bool isFilePathMatchedByGlobList(
      String filePath, String fileName, List<Glob> globList) {
    var isTake = (globList == _options.takeFileGlobList);

    for (var glob in globList) {
      if (_logger.isVerbose) {
        _logger.verbose(
            '...matching against ${isTake ? 'take' : 'skip'}-glob: ${glob.pattern}');
      }

      var hasDir = glob.pattern.contains(PathExt.separatorPosix);

      var isMatch = (hasDir ? glob.matches(filePath) : glob.matches(fileName));
      var isValid = (isTake == isMatch);

      if (!isValid) {
        if (_logger.isVerbose) {
          _logger.verbose('...${isTake ? 'not ' : ''}matched - skipping');
        }
        return isMatch;
      }
    }

    return isTake;
  }

  /// Match [filePath] or [fileName] against every regular expression pattern in [regexList]
  /// (stop when the first no-match encountered)
  ///
  bool isFilePathMatchedByRegexList(String filePath, String fileName, List<RegExp> regexList) {
    var isTake = (regexList == _options.takeFileRegexList);

    for (var regex in regexList) {
      if (_logger.isVerbose) {
        _logger.verbose(
            '...matching against ${isTake ? 'take' : 'skip'}-regex: ${regex.pattern}');
      }

      var hasDir = regex.pattern.contains(PathExt.separatorPosixEscaped);

      var isMatch =
          (hasDir ? regex.hasMatch(filePath) : regex.hasMatch(fileName));
      var isValid = (isTake == isMatch);

      if (!isValid) {
        if (_logger.isVerbose) {
          _logger.verbose('...${isTake ? 'not ' : ''}matched - skipping');
        }
        return isMatch;
      }
    }

    return isTake;
  }
}
