// Copyright (c) 2022, Alexander Iurovetski
// All rights reserved under MIT license (see LICENSE file)
//

import 'package:chest/register_services.dart';
import 'package:file/file.dart';
import 'package:file_ext/file_ext.dart';
import 'package:thin_logger/thin_logger.dart';

/// Class for the formatted output
///
class Printer {
  /// Const: default format showing content
  ///
  static const defaultFormatContent = fstrPath + defaultSeparator + fstrContent;

  /// Const: default format showing count only
  ///
  static const defaultFormatCount = fstrCount + defaultSeparator + fstrPath;

  /// Const: default separator
  ///
  static const defaultSeparator = ':';

  /// Const: formatter for the content text
  ///
  static const fstrContent = 't';

  /// Const: formatter for the count
  ///
  static const fstrCount = 'c';

  /// Const: formatter for the line no
  ///
  static const fstrLineNo = 'l';

  /// Const: formatter for the file name
  ///
  static const fstrName = 'n';

  /// Const: formatter for the file path
  ///
  static const fstrPath = 'p';

  /// Actual format to use
  ///
  String get format => _format;
  var _format = defaultFormatContent;

  /// List of format infos
  ///
  List<PrinterFormatItem> get formatItems => _formatItems;
  final _formatItems = <PrinterFormatItem>[];

  /// Actual format to use
  ///
  bool isPathAllowed = true;

  /// [format]-based flag: true = content will be printed
  ///
  bool get showContent => _showContent;
  var _showContent = false;

  /// [format]-based flag: true = count will be printed
  ///
  bool get showCount => _showCount;
  var _showCount = false;

  /// [format]-based flag: true = filename will be printed
  ///
  bool get showLineNo => _showLineNo;
  var _showLineNo = false;

  /// [format]-based flag: true = filename will be printed
  ///
  bool get showName => _showName;
  var _showName = false;

  /// [format]-based flag: true = full path will be printed
  ///
  bool get showNameOrPath => _showNameOrPath;
  var _showNameOrPath = false;

  /// [format]-based flag: true = filename or full path will be printed
  ///
  bool get showPath => _showPath;
  var _showPath = false;

  /// Dependency injection
  ///
  final _logger = services.get<Logger>();

  /// Dependency injection
  ///
  late final _fileSystem = services.get<FileSystem>();

  /// Default constructor
  ///
  Printer(String? format, {bool isPathAllowed = true}) {
    setFormat(format, isPathAllowed: isPathAllowed);
  }

  /// Actual printing
  ///
  void out({String? path, int? lineNo, String? text, int? count}) => _logger
      .out(formatData(path: path, lineNo: lineNo, content: text, count: count));

  /// Format the output string
  ///
  String formatData({String? path, int? lineNo, String? content, int? count}) {
    var lines = (content ?? '').split(StdinExt.newLine);
    var prevSuffix = '';
    var result = '';

    if (lineNo != null) {
      --lineNo;
    }

    for (var line in lines) {
      if (lineNo != null) {
        ++lineNo;
      }

      for (var item in _formatItems) {
        var field = '';

        switch (item.fstr) {
          case fstrCount:
            if ((count == null) || (count < 0)) {
              continue;
            }
            field = count.toString();
            break;
          case fstrLineNo:
            if ((lineNo == null) || (lineNo <= 0)) {
              continue;
            }
            field = lineNo.toString();
            break;
          case fstrName:
          case fstrPath:
            if (!isPathAllowed || (path == null)) {
              continue;
            }
            if (path.isEmpty || (path == StdinExt.name)) {
              continue;
            }
            field = (item.fstr == fstrPath ? path : _fileSystem.path.basename(path));
            break;
          case fstrContent:
            if (line.isEmpty) {
              continue;
            }
            field = line;
            break;
          default:
            continue;
        }

        if (prevSuffix.isNotEmpty) {
          result += prevSuffix;
        }

        if (field.isNotEmpty) {
          result += field;
        }

        prevSuffix = item.suffix;
      }
    }

    return result;
  }

  /// Format parser
  ///
  void _parseFormatItems() {
    _formatItems.clear();

    for (var start = 0, end = 0, len = _format.length; end < len; end++) {
      final curChar = _format[end];
      var isPath = false;

      switch (curChar) {
        case fstrContent:
        case fstrCount:
        case fstrLineNo:
          break;
        case fstrName:
          isPath = true;
          break;
        case fstrPath:
          isPath = true;
          break;
        default:
          continue;
      }

      final lastNo = _formatItems.length - 1;
      final suffix = (end > start ? _format.substring(start, end) : '');

      if (suffix.isNotEmpty) {
        if (lastNo >= 0) {
          _formatItems[lastNo].suffix = suffix;
        } else {
          _formatItems.add(PrinterFormatItem('', suffix: suffix));
        }
      }

      if (!isPath || isPathAllowed) {
        _formatItems.add(PrinterFormatItem(curChar, suffix: ''));
      }

      start = end + 1;
    }
  }

  /// Default initializer
  ///
  void setFormat(String? format, {bool isPathAllowed = true}) {
    if ((format == null) || format.trim().isEmpty) {
      _format = defaultFormatContent;
    } else {
      _format = format;
    }

    this.isPathAllowed = isPathAllowed;

    _showCount = _format.contains(fstrCount);
    _showContent = _format.contains(fstrContent);
    _showLineNo = _format.contains(fstrLineNo);
    _showName = _format.contains(fstrName);
    _showPath = _format.contains(fstrPath);
    _showNameOrPath = (_showName || _showPath);

    _parseFormatItems();
  }
}

/// Supplementary class for the formatted output
///
class PrinterFormatItem {
  var fstr = '';
  var suffix = '';

  PrinterFormatItem(this.fstr, {this.suffix = ''});

  @override
  String toString() => '$fstr,$suffix';
}

/// Supplementary class for the formatted output
///
extension PrinterFormatItemList on List<PrinterFormatItem> {
  List<String> toStringList() => map((x) => x.toString()).toList();
}
