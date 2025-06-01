// Copyright (c) 2022-2023, Alexander Iurovetski
// All rights reserved under MIT license (see LICENSE file)

import 'dart:io';
import 'package:chest/chest_match.dart';
import 'package:chest/options.dart';
import 'package:chest/printer.dart';
import 'package:chest/register_services.dart';
import 'package:file/file.dart';
import 'package:file_ext/file_ext.dart';
import 'package:glob/glob.dart';
import 'package:loop_visitor/loop_visitor.dart';
import 'package:thin_logger/thin_logger.dart';
import 'package:utf_ext/utf_ext.dart';

/// A class to scan files or stdin, filter strings and optionally, count those
///
class Scanner {
  /// The way to output result
  ///
  Printer get printer => _printer;
  late final Printer _printer;

  // Dependency injection
  //
  final _fileSystem = services.get<FileSystem>();
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
      count = await execEachFileInList(_options.roots, null, _options.globs);
    } else if (_options.isXargs) {
      count = await execEachFileInStdin();
    } else {
      count = await execContentInStdin();
    }

    final isSuccess = _isExpected(count);

    if (_options.isCount && !_options.isContent) {
      _printer.out(count: count);
    }

    return isSuccess;
  }

  /// Read content from stdin line by line, filter those and, optionally, count
  ///
  Future<int> execContentInStdin() async {
    var count = 0;

    if (_logger.isVerbose) {
      _logger.verbose('Scanning the content of ${UtfStdin.name}');
    }

    if (_options.isMultiLine) {
      var pileup = StringBuffer();
      await stdin.readUtfAsString(pileup: pileup);
      count = execMultiLine('', pileup.toString());
    } else {
      await stdin.readUtfAsLines(onRead: (params) async {
        count += execLine('', params.currentNo, params.current!);
        return VisitResult.skip;
      });
    }

    return count;
  }

  /// Read and filter the list of files from stdin, then process each of those
  ///
  Future<int> execEachFileInList(
      List<String>? roots, Glob? filter, List<Glob>? filters) async {
    if (_logger.isVerbose) {
      final f = filters ?? [filter ?? Glob('*')];
      final r = roots == null || roots.isEmpty ? ['.'] : roots;
      _logger.verbose('Processing $f under $r');
    }

    var count = 0;
    var flags = FileSystemExt.followLinks;

    if (_options.isHiddenAllowed) {
      flags = flags | FileSystemExt.allowHidden;
    }

    await _fileSystem.forEachEntity(
        roots: roots,
        filter: filter,
        filters: filters,
        type: FileSystemEntityType.file,
        flags: flags,
        onEntity: (fileSystem, entity, stat) async {
          if (entity != null) {
            count += await execFile(entity.path);
          }
          return VisitResult.skip;
        },
        onException: (fileSystem, entity, stat, ex, stackTrace) async {
          final path = (entity == null ? '' : ' in "${entity.path}"');
          _logger.error('Error$path: $ex');

          return VisitResult.skip;
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

    await stdin.readUtfAsLines(onRead: (params) async {
      final filter = _fileSystem.path.toGlob(params.current);
      count += await execEachFileInList(null, filter, null);
      return VisitResult.skip;
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

    var count = 0;

    if (_options.isMultiLine) {
      var pileup = StringBuffer();
      await file.readUtfAsString(pileup: pileup);
      count += execMultiLine(filePath, pileup.toString());
    } else {
      await file.readUtfAsLines(onRead: (params) async {
        count += execLine(filePath, params.currentNo, params.current!);
        return VisitResult.skip;
      });
    }

    if (_logger.isVerbose) {
      _logger.verbose('...count: $count');
    }

    if (_options.isCount) {
      _printer.out(path: filePath, count: count);
    }

    return (count > 0 ? (_options.isCount ? count : 1) : 0);
  }

  /// Check single [line] and print details if matched
  ///
  int execLine(String filePath, int lineNo, String line) {
    if (_logger.isVerbose) {
      _logger.verbose('Validating the line: $line');
    }

    var count = 0;
    var start = 0;

    while (true) {
      final match = firstMatch(line, start);

      if (match == null) {
        break;
      }

      ++count;
      start = match.end;

      if (_printer.showMatchOnly) {
        final text = line.substring(match.start, match.end);
        _printer.out(path: filePath, lineNo: lineNo, text: text);
      }
    }

    if (_logger.isVerbose) {
      _logger.verbose('...${count > 0 ? '' : 'not '}matched');
    }

    if (!_options.isCount && !_printer.showMatchOnly) {
      _printer.out(path: filePath, count: count, lineNo: lineNo, text: line);
    }

    return count;
  }

  /// Check whole [content] and print all matching details
  ///
  int execMultiLine(String filePath, String content) {
    if (_logger.isVerbose) {
      _logger.verbose('Validating the content of: $filePath');
    }

    var lineStarts = getLineStarts(filePath, content);

    if (lineStarts.isEmpty) {
      return 0;
    }

    ChestMatch? match;
    final lineStartCount = lineStarts.length;
    final length = content.length;
    var next = -1;
    var start = 0;

    for (; start < length; start = next) {
      match = firstMatch(content, start);

      if (match == null) {
        break;
      }

      final startLineNo = findLineStartIndex(
          content, match.start, false, lineStarts, lineStartCount);

      if (_printer.showMatchOnly) {
        final text = content.substring(match.start, match.end);
        _printer.out(path: filePath, lineNo: startLineNo, text: text);
        next = match.end;
        continue;
      }

      final nextLineNo = findLineStartIndex(
          content, match.end, true, lineStarts, lineStartCount);

      start = lineStarts[startLineNo];
      next = lineStarts[nextLineNo];

      if ((start <= 0) || (next <= 0)) {
        break;
      }

      if (!_options.isCount) {
        _printer.out(
            path: filePath,
            count: 1,
            lineNo: startLineNo + 1,
            text: content.substring(start, next - 1));
      }
    }

    final isFound = ((match != null) || (start > 0));

    if (_logger.isVerbose) {
      _logger.verbose('...${isFound ? '' : 'not '}matched');
    }

    return (isFound ? 1 : 0);
  }

  /// Find the start of the line in [input] before or after position [from]
  ///
  int findLineStartIndex(
      String input, int from, bool after, List<int> lineStarts, int count) {
    for (var i = 1; i < count; i++) {
      if (lineStarts[i] > from) {
        return (after ? i : i - 1);
      }
    }

    return -1;
  }

  /// Check [input] and print details if matched
  ///
  ChestMatch? firstMatch(String input, [int start = 0]) {
    ChestMatch? match;
    String inputLC;

    if (_options.hasPlain && _options.hasCaseInsensitive) {
      inputLC = input.toLowerCase();
    } else {
      inputLC = '';
    }

    for (var patternList in _options.patterns) {
      for (var pattern in patternList) {
        if (_logger.isVerbose) {
          if (pattern.regex != null) {
            _logger.verbose('...matching against regex: ${pattern.regex}');
          } else {
            _logger.verbose('...matching against plain text: ${pattern.plain}');
          }
        }

        final inputEx = pattern.caseSensitive ? input : inputLC;
        match = pattern.firstMatch(inputEx, start);

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

  /// Make the list of positions wheer every line starts
  ///
  List<int> getLineStarts(String filePath, String content) {
    var lineStarts = <int>[];

    if (content.isEmpty) {
      return lineStarts;
    }

    lineStarts.add(0);

    var end = 0;

    while (true) {
      end = content.indexOf(UtfConst.lineBreak, end);

      if (end < 0) {
        break;
      }

      lineStarts.add(++end);
    }

    return lineStarts;
  }

  /// Check the actual count is within the expected b0undaries
  ///
  bool _isExpected(int actual) {
    if ((_options.min >= 0) && (actual < _options.min)) {
      return false;
    }

    if ((_options.max >= 0) && (actual > _options.max)) {
      return false;
    }

    return true;
  }
}
