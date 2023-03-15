// Copyright (c) 2022-23, Alexander Iurovetski
// All rights reserved under MIT license (see LICENSE file)
//

import 'package:chest/printer_format_item.dart';
import 'package:chest/register_services.dart';
import 'package:file/file.dart';
import 'package:thin_logger/thin_logger.dart';
import 'package:utf_ext/utf_ext.dart';

/// Class for the formatted output
///
class Printer {
  /// Const: default separator
  ///
  static var defaultSeparator = ',';

  /// Const: empty string
  ///
  static const empty = '';

  /// Const: format character
  ///
  static const formatChar = '%';

  /// Const: RegExp to break into fields
  ///
  static final _formatParseRE =
      RegExp('([^$formatChar]*)($formatChar.)([^$formatChar]*)');

  /// Const: formatter for the content text
  ///
  static const fstrContent = '${formatChar}s';

  /// Const: formatter for the count
  ///
  static const fstrCount = '${formatChar}c';

  /// Const: formatter for the line break
  ///
  static const fstrLineBreak = '${formatChar}n';

  /// Const: formatter for the line no
  ///
  static const fstrLineNo = '${formatChar}l';

  /// Const: formatter for the file name
  ///
  static const fstrName = '${formatChar}f';

  /// Const: formatter for the file path
  ///
  static const fstrPath = '${formatChar}p';

  /// Const: formatter for the percentage sign
  ///
  static const fstrPercent = '$formatChar$formatChar';

  /// Const: formatter for the line break
  ///
  static const fstrTab = '${formatChar}t';

  /// Actual format to use
  ///
  String get format => _format;
  var _format = getDefaultFormat();

  /// List of format infos
  ///
  List<PrinterFormatItem> get formatItems => _formatItems;
  final _formatItems = <PrinterFormatItem>[];

  /// Default format showing content
  ///
  static String getDefaultFormat() => fstrPath + defaultSeparator + fstrContent;

  /// Default format showing count only
  ///
  static String getDefaultFormatForCount() =>
      fstrCount + defaultSeparator + fstrPath;

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
  Printer(String? format) {
    setFormat(format);
  }

  /// Actual printing
  ///
  void out({String? path, int? lineNo, String? text, int? count}) => _logger
      .out(formatData(path: path, lineNo: lineNo, content: text, count: count));

  /// Format the output string
  ///
  String formatData({String? path, int? lineNo, String? content, int? count}) {
    var hasPath = _showNameOrPath && ((path != null) && path.isNotEmpty);

    if (lineNo != null) {
      --lineNo;
    }

    var lines = (content == null ? [null] : content.split(UtfConst.lineBreak));
    String? pileup;
    var result = empty;

    for (var line in lines) {
      if (lineNo != null) {
        ++lineNo;
      }

      if (result.isNotEmpty) {
        result += UtfConst.lineBreak;
      }

      PrinterFormatItem? currItem;
      final lastNo = _formatItems.length - 1;

      for (var i = 0; i <= lastNo; i++) {
        currItem = _formatItems[i];
        String? value;

        switch (currItem.fstr) {
          case fstrContent:
            value = line;
            break;
          case fstrCount:
            value = count?.toString();
            break;
          case fstrLineNo:
            value = lineNo?.toString();
            break;
          case fstrName:
            value = (hasPath ? _fileSystem.path.basename(path) : null);
            break;
          case fstrPath:
            value = (hasPath ? path : null);
            break;
          default:
            if (currItem.prefix.isNotEmpty) {
              pileup ??= empty;
              pileup += currItem.prefix;
            }
            if (currItem.suffix.isNotEmpty) {
              pileup ??= empty;
              pileup += currItem.suffix;
            }
            if ((i == lastNo) && (pileup != null)) {
              result += pileup;
            }
            continue;
        }

        if (value == null) {
          continue;
        }

        if (pileup != null) {
          result += pileup;
        }

        if (currItem.prefix.isNotEmpty) {
          result += currItem.prefix;
        }

        result += value;

        if (currItem.suffix.isNotEmpty) {
          if (i == lastNo) {
            result += currItem.suffix;
          } else {
            pileup = currItem.suffix;
          }
        } else {
          pileup = null;
        }
      }
    }

    return result;
  }

  /// Default format items initializer
  ///
  void setFormat(String? format) {
    _initFormat(format);
    _parseFormatItems();

    _showCount = _format.contains(fstrCount);
    _showContent = _format.contains(fstrContent);
    _showLineNo = _format.contains(fstrLineNo);
    _showName = _format.contains(fstrName);
    _showPath = _format.contains(fstrPath);
    _showNameOrPath = (_showName || _showPath);
  }

  /// If no formatter found, then treat [_format] as a separator, and
  /// reset that with the default format with the default separator
  /// replaced with the original [_format]\
  /// \
  /// Replace all special character formatters with the actual characters
  ///
  void _initFormat(String? format) {
    final isFormat = ((format != null) && format.trim().isNotEmpty);

    _format = (isFormat ? format : getDefaultFormat())
        .replaceAll(fstrPercent, '\x01')
        .replaceAll(fstrLineBreak, UtfConst.lineBreak)
        .replaceAll(fstrTab, '\t')
        .replaceAll('\x01', fstrPercent);

    if (!_format.contains(formatChar)) {
      defaultSeparator = _format;
      _format = getDefaultFormat();
    }
  }

  /// Breaks [_format] into [_formatItems]
  ///
  void _parseFormatItems() {
    _formatItems.clear();

    _format.replaceAllMapped(_formatParseRE, (match) {
      var prefix = match.group(1) ?? empty;
      var fstr = match.group(2) ?? empty;
      var suffix = match.group(3) ?? empty;

      final lastItemNo = _formatItems.length - 1;
      final lastItem = (lastItemNo < 0 ? null : _formatItems[lastItemNo]);

      if ((lastItem == null) || lastItem.fstr.isNotEmpty || fstr.isNotEmpty) {
        _formatItems.add(PrinterFormatItem(prefix, fstr, suffix));
      } else {
        lastItem.prefix += prefix;
        lastItem.suffix += suffix;
      }

      return empty;
    });
  }
}
