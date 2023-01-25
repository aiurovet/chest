// Copyright (c) 2022, Alexander Iurovetski
// All rights reserved under MIT license (see LICENSE file)

import 'dart:convert';
import 'dart:io';
import 'package:chest/chest_match.dart';
import 'package:chest/printer.dart';
import 'package:file/file.dart';
import 'package:file_ext/file_ext.dart';
import 'package:glob/glob.dart';
import 'package:chest/register_services.dart';
import 'package:chest/options.dart';
import 'package:parse_args/parse_args.dart';
import 'package:thin_logger/thin_logger.dart';

/// A class to scan files or stdin, filter strings and optionally, count those
///
class Scanner {
  /// The way to output result
  ///
  Printer get printer => _printer;
  late final Printer _printer;

  // Private: line separator
  //
  static const _newLine = StdinExt.newLine;

  // Dependency injection
  //
  final _fileSystem = services.get<FileSystem>();
  final _lineSplitter = services.get<LineSplitter>();
  final _logger = services.get<Logger>();
  final _options = services.get<Options>();

  /// Default constructor
  ///
  Scanner();

  /// The execution start point
  ///
  Future<bool> exec() async {
    _printer = _options.printer;

    var count = 0;
    var hasFiles = _options.globs.isNotEmpty;

    if (hasFiles) {
      count = await execEachFileInGlobList();
    } else if (_options.isXargs) {
      count = await execEachFileInStdin();
    } else {
      count = await execStdin();
    }

    final max = _options.max;
    final min = _options.min;

    if ((min < 0) && (max < 0)) {
      if (_options.isCount) {
        _printer.out(count: count);
      }
      return true;
    }

    var isSuccess = ((count >= min) && ((max < 0) || (count <= max)));

    var isMin = (max < 0);
    var isEqu = (max == min);

    var details = (isMin
        ? '$count (actual) >= $min (min)'
        : isEqu
            ? '$count (actual) == $min (expected)'
            : '$min (min) <= $count (actual) <= $max (max)');

    _logger.info(
        '${Options.appName}: ${isSuccess ? 'succeeded' : 'failed'}: $details');

    return isSuccess;
  }

  /// Read and filter the list of files defined by options, then process each of those
  ///
  Future<int> execEachFile(Glob glob) async {
    if (_logger.isVerbose) {
      _logger
          .verbose('Scanning the content of files filtered by ${glob.pattern}');
    }

    var isHiddenAllowed = _options.isHiddenAllowed;
    var entities = glob.listFileSystem(_fileSystem);
    var curDirName = _fileSystem.path.current;
    var count = 0;

    await for (var entity in entities) {
      var path = entity.path;
      path = _fileSystem.path.normalize(
          _fileSystem.path.isAbsolute(path) ? path : _fileSystem.path.join(curDirName, path));

      if (!isHiddenAllowed && _fileSystem.path.basename(path).startsWith('.')) {
        continue;
      }

      if (_logger.isVerbose) {
        _logger.verbose('Checking "$path" is a file');
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

      count += await execFile(path, isCheckRequired: false);
    }

    return count;
  }

  /// Read and filter the list of files from stdin, then process each of those
  ///
  Future<int> execEachFileInGlobList() async {
    if (_logger.isVerbose) {
      _logger.verbose('Executing all files listed matching the glob list');
    }

    var count = 0;
    var flags = FileSystemExt.followLinks;

    if (_options.isHiddenAllowed) {
      flags = flags | FileSystemExt.allowHidden;
    }

    await _fileSystem.forEachEntity(
      roots: _options.roots,
      filters: _options.globs,
      type: FileSystemEntityType.file,
      flags: flags,
      entityHandler: (fileSystem, entity, stat) async {
        if (entity != null) {
          count += await execFile(entity.path);
        }
        return true;
      },
      exceptionHandler: (fileSystem, entity, stat, e, stackTrace) async {
        if (entity != null) {
          _logger.error('Failed processing "${entity.path}": ${e.toString()}');
        } else {
          _logger.error(e.toString());
        }
        return true;
      });

    return count;
  }

  /// Read and filter the list of files from stdin, then process each of those
  ///
  Future<int> execEachFileInStdin() async {
    if (_logger.isVerbose) {
      _logger.verbose('Scanning the content of files listed in stdin');
    }

    var count = 0;

    await stdin.forEachLine(handler: (line) async {
      count += await execEachFile(GlobExt.create(_fileSystem, line));
      return true;
    });

    return count;
  }

  /// Check the file defined by [filePath] exists if [isCheckRequired] is set.
  /// Then process the file: read it line by line filtering those through the
  /// patterns and, optionally, count matches.
  ///
  Future<int> execFile(String filePath, {bool isCheckRequired = false}) async {
    if (!_options.isContent) {
      if (!_options.isCount) {
        _printer.out(path: filePath);
      }
      return 1;
    }

    if (_logger.isVerbose) {
      _logger.verbose('Scanning the file "$filePath"');
    }

    var file = _fileSystem.file(filePath);

    if (isCheckRequired && !(await file.exists())) {
      throw Exception('File not found: "${file.path}"');
    }

    var lines =
        file.openRead().transform(utf8.decoder).transform(_lineSplitter);

    var count = 0;

    count += await execFileLines(filePath, lines);

    if (_logger.isVerbose) {
      _logger.verbose('...count: $count');
    }

    if (_options.isCount) {
      _printer.out(path: filePath, count: count);
    }

    return (count > 0 ? 1 : 0);
  }

  /// Read the whole content of [filePath] and print all matching details
  ///
  Future<int> execFileLines(String filePath, Stream<String> lines) async {
    if (!_options.isMultiLine) {
      var count = 0;

      await for (var line in lines) {
        count += execLine(filePath, line);
      }

      return count;
    }

    var content = '';
    var lineStarts = <int>[];
    var end = 0;

    await for (var line in lines) {
      if (end > 0) {
        content += _newLine;
      }

      content += line;

      lineStarts.add(end);
      end += line.length + 1;
    }

    lineStarts.add(content.length);

    return execMultiLine(filePath, content, lineStarts);
  }

  /// Check single [line] and print details if matched
  ///
  int execLine(String filePath, String line) {
    if (_logger.isVerbose) {
      _logger.verbose('Validating the line: $line');
    }

    if (!_options.isContent) {
      if (_logger.isVerbose) {
        _logger.verbose('...counting only');
      }
      return 1;
    }

    final hasMatch = (firstMatch(line) != null);

    if (_logger.isVerbose) {
      _logger.verbose('...${hasMatch ? '' : 'not '} matched');
    }

    if (!hasMatch) {
      return 0;
    }

    if (!_options.isCount) {
      _printer.out(path: filePath, text: line);
    }

    return 1;
  }

  /// Check whole [content] and print all matching details
  ///
  int execMultiLine(String filePath, String content, List<int> lineStarts) {
    if (_logger.isVerbose) {
      _logger.verbose('Validating the content of: $filePath');
    }

    if (!_options.isContent) {
      if (_logger.isVerbose) {
        _logger.verbose('...counting only');
      }
      return 1;
    }

    ChestMatch? match;
    var lineEnd = -1;
    var lastLineStartNo = -1;
    final lineStartCount = lineStarts.length - 1;
    final length = content.length;

    for (var start = 0; (start < length); start = lineEnd) {
      final match = firstMatch(content, start);

      if (match == null) {
        break;
      }

      for (; lastLineStartNo < lineStartCount; lastLineStartNo++) {
        if (lineStarts[lastLineStartNo] > start) {
          --lastLineStartNo;
          break;
        }
      }

      lineEnd = lineStarts[lastLineStartNo + 1];

      if (lineEnd <= 0) {
        break;
      }

      if (!_options.isCount) {
        _printer.out(
            path: filePath,
            text: content.substring(lineStarts[lastLineStartNo], lineEnd));
      }
    }

    if (_logger.isVerbose) {
      _logger.verbose('...${match == null ? 'not ' : ''} matched');
    }

    if (match == null) {
      return 0;
    }

    return 1;
  }

  /// Read content from stdin line by line, filter those and, optionally, count
  ///
  Future<int> execStdin() async {
    var count = 0;

    if (_logger.isVerbose) {
      _logger.verbose('Scanning the content of stdin');
    }

    if (_options.isMultiLine) {
      var content = '';
      var lineStarts = <int>[];
      var end = 0;

      await stdin.forEachLine(handlerSync: (line) {
        if (end > 0) {
          content += _newLine;
        }

        content += line;

        lineStarts.add(end);
        end += line.length + 1;

        return true;
      });

      lineStarts.add(content.length);

      count = execMultiLine('', content, lineStarts);
    } else {
      await stdin.forEachLine(handlerSync: (line) {
        count += execLine('', line);
        return true;
      });
    }

    if (_options.isCount) {
      _printer.out(count: count);
    }

    return count;
  }

  /// Check [input] and print details if matched
  ///
  ChestMatch? firstMatch(String input, [int start = 0]) {
    ChestMatch? match;
    var inputLC = (_options.hasCaseInsensitive ? input.toLowerCase() : '');

    for (var patternList in _options.patterns) {
      for (var pattern in patternList) {
        if (_logger.isVerbose) {
          if (pattern.regex != null) {
            _logger.verbose('...matching against regex: ${pattern.regex}');
          } else {
            _logger.verbose('...matching against plain text: ${pattern.plain}');
          }
        }

        match = pattern.firstMatch(pattern.caseSensitive ? input : inputLC,
            start: start);

        if (_logger.isVerbose) {
          _logger.verbose('......${(match == null ? 'not ' : '')}matched');
        }

        if (match == null) {
          break;
        }
      }
      if (match != null) {
        break;
      }
    }

    if (_logger.isVerbose) {
      _logger.verbose('...${match == null ? 'not ' : ''}matched');
    }

    return match;
  }
}
