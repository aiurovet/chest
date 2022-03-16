import 'dart:io';

import 'package:glob/glob.dart';
import 'package:parse_args/parse_args.dart';

import 'package:chest/ext/glob.dart';
import 'package:chest/ext/path.dart';
import 'package:chest/ext/string.dart';
import 'package:chest/logger.dart';

class Options {

  //////////////////////////////////////////////////////////////////////////////

  static const String appName = 'chest';
  static const String appVersion = '0.1.0';

  //////////////////////////////////////////////////////////////////////////////

  static const String charOption = '-';
  static const String endOption = '--';

  static const String charInsensitive = 'i';
  static const String charSensitive = ' ';

  //////////////////////////////////////////////////////////////////////////////

  var _isCount = false;
  get isCount => _isCount;

  var _isPathsOnly = false;
  get isPathsOnly => _isPathsOnly;

  var _isTakeFileListFromStdin = false;
  get isTakeFileListFromStdin => _isTakeFileListFromStdin;

  int _max = -1;
  int get max => _max;

  int _min = 0;
  int get min => _min;

  final _skipFileGlobList = <Glob>[];
  get skipFileGlobList => _skipFileGlobList;

  final _skipFileRegexList = <RegExp>[];
  get skipFileRegexList => _skipFileRegexList;

  final _skipTextPlainList = <String>[];
  get skipTextPlainList => _skipTextPlainList;

  final _skipTextRegexList = <RegExp>[];
  get skipTextRegexList => _skipTextRegexList;

  final _takeFileGlobList = <Glob>[];
  get takeFileGlobList => _takeFileGlobList;

  final _takeFileRegexList = <RegExp>[];
  get takeFileRegexList => _takeFileRegexList;

  final _takeTextPlainList = <String>[];
  get takeTextPlainList => _takeTextPlainList;

  final _takeTextRegexList = <RegExp>[];
  get takeTextRegexList => _takeTextRegexList;

  //////////////////////////////////////////////////////////////////////////////

  Logger _logger = Logger();

  //////////////////////////////////////////////////////////////////////////////

  Options([Logger? log]) {
    if (log != null) {
      _logger = log;
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  Future parseAppArgs(List<String> args) async {
    var argCount = args.length;

    if (argCount <= 0) {
      printUsage();
    }

    parseLogArgs(args);

    var dirName = '';

    parseArgs(args, (optName, valueList) {
      if (_logger.isDebug) {
        _logger.debug('Option values: $valueList');
      }

      switch (optName) {
        case '?':
        case 'help':
          printUsage();

        // Initial location

        case 'dir':
          dirName = _getString(optName, valueList);
          break;

        // Expected count range

        case 'max':
          _isCount = true;
          _max = _getInt(optName, valueList, defValue: _max);
          break;
        case 'min':
          _isCount = true;
          _min = _getInt(optName, valueList, defValue: _min);
          break;

        // Output style

        case 'nocontent':
          _isPathsOnly = true;
          break;

        // Plain take-filters for text

        case 'plain':
          _getTextPlainList(_takeTextPlainList, valueList, isCaseSensitive: true);
          break;
        case 'iplain':
          _getTextPlainList(_takeTextPlainList, valueList, isCaseSensitive: false);
          break;

        // Plain skip-filters for text

        case 'noplain':
          _getTextPlainList(_skipTextPlainList, valueList, isCaseSensitive: true);
          break;
        case 'inoplain':
        case 'noiplain':
          _getTextPlainList(_skipTextPlainList, valueList, isCaseSensitive: false);
          break;

        // Regex take-filters for text

        case 'regex':
          _getTextRegexList(_takeTextRegexList, valueList, isCaseSensitive: true);
          break;
        case 'iregex':
          _getTextRegexList(_takeTextRegexList, valueList, isCaseSensitive: false);
          break;

        // Regex skip-filters for text

        case 'noregex':
          _getTextRegexList(_skipTextRegexList, valueList, isCaseSensitive: true);
          break;
        case 'inoregex':
        case 'noiregex':
          _getTextRegexList(_skipTextRegexList, valueList, isCaseSensitive: false);
          break;

        // Glob take-filters for files

        case 'take':
          _getFileGlobList(_takeFileGlobList, valueList, isTake: true);
          break;
        case 'itake':
          _getFileGlobList(_takeFileGlobList, valueList, isTake: true, isCaseSensitive: false);
          break;

        // Regex take-filters for files

        case 'rtake':
          _getFileRegexList(_takeFileRegexList, valueList, isTake: true);
          break;
        case 'irtake':
        case 'ritake':
          _getFileRegexList(_takeFileRegexList, valueList, isTake: true, isCaseSensitive: false);
          break;

        // Glob skip-filters for files

        case 'skip':
          _getFileGlobList(_skipFileGlobList, valueList, isTake: false);
          break;
        case 'iskip':
          _getFileGlobList(_skipFileGlobList, valueList, isTake: false, isCaseSensitive: false);
          break;

        // Regex skip-filters for files

        case 'rskip':
          _getFileRegexList(_skipFileRegexList, valueList, isTake: false);
          break;
        case 'irskip':
        case 'riskip':
          _getFileRegexList(_skipFileRegexList, valueList, isTake: false, isCaseSensitive: false);
          break;

        // Logging - processed already

        case 'debug':
        case 'verbosity':
          break;

        // Bad

        default:
          printUsage('Unknown option "$optName"');
      }

      return true;
    });

    // Post-parsing

    await setCurrentDirectory(dirName);
  }

  //////////////////////////////////////////////////////////////////////////////

  void parseLogArgs(List<String> args) {
    parseArgs(args, (optName, values) {
      if (values.isNotEmpty) {
        printUsage('Option "$optName" has unexpected value(s): $values');
      }
      switch (optName) {
        case 'q':
        case 'quiet':
          _logger.level = Logger.levelSilent;
          break;
        case 'v':
        case 'verbose':
          _logger.level = Logger.levelDebug;
          break;
      }
      return true;
    });
  }

  //////////////////////////////////////////////////////////////////////////////

  Never printUsage([String? error]) {
    _logger.error('''
$appName $appVersion (c) Alexander Iurovetski 2022

Check Strings: a command-line utility to read text from files or ${StringExt.stdinDisplay} and filter the content based on plain text or regular expression, then, optionally, check that the number of matching lines is within the specified range

USAGE:

$appName [OPTIONS]

-?, -h, --help         - this help screen
-d, --dir      <DIR>   - directory to start in
-m, --min      <INT>   - minimum expected number of matching lines
-M, --max      <INT>   - maximum expected number of matching lines
-p, --plain    <TEXT>  - print lines matching plain text, case-sensitive
-P, --iplain   <TEXT>  - print lines matching plain text, case-insensitive
-a, --noplain  <TEXT>  - print lines matching plain text, case-sensitive
-A, --inoplain <TEXT>  - print lines not matching plain text, case-insensitive
    --noiplain <TEXT>  - same as --inoplain
-r, --regex    <REGEX> - print lines matching regular expression, case-sensitive
-R, --iregex   <REGEX> - print lines matching regular expression, case-insensitive
-n, --noregex  <REGEX> - print lines not matching regular expression, case-sensitive
-N, --inoregex <REGEX> - print lines not matching regular expression, case-insensitive
    --noiregex <REGEX> - same as --inoregex
-q, --quiet            - quiet mode (no output, same as verbosity 0 or "quiet")
-t, --take     <GLOB>  - include filename(s) defined by glob pattern, OS-specific case
-T, --itake    <GLOB>  - include filename(s) defined by glob pattern, case-insensitive
-s, --skip     <GLOB>  - exclude filename(s) defined by glob pattern, OS-specific case
-S, --iskip    <GLOB>  - exclude filename(s) defined by glob pattern, case-insensitive

If the value of -t/--take or -T/--itake option is ${StringExt.stdinPath}, treat ${StringExt.stdinDisplay} as the list of files to process
If neither -t/--take, nor -T/--itake option specified, read and filter text from ${StringExt.stdinDisplay}
'''
    );

    if (error != null) {
      throw Exception(error);
    }

    exit(1);
  }

  //////////////////////////////////////////////////////////////////////////////

  Future setCurrentDirectory(String? dirName) async {
    if (_logger.isDebug) {
      _logger.debug('Arg start dir: ${dirName == null ? StringExt.unknown : '"$dirName"'}\n');
    }

    if ((dirName == null) || dirName.isBlank()) {
      dirName = Path.currentDirectory.path;
    }
    else {
      var dir = Path.fileSystem.directory(dirName);

      if (!await dir.exists()) {
        throw Exception('Directory is not found: "$dirName"');
      }

      Path.currentDirectory = dir;

      if (_logger.isDebug) {
        _logger.debug('Switching to dir: "$dirName"\n');
      }
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  int _getInt(String optName, List<String> valueList, {int defValue = 0}) =>
    (int.tryParse(_getString(optName, valueList)) ?? defValue);

  //////////////////////////////////////////////////////////////////////////////

  String _getString(String optName, List<String> valueList) {
    if (valueList.isEmpty) {
      printUsage('Option "$optName" is expected to have a value"}');
    }

    return valueList[0];
  }

  //////////////////////////////////////////////////////////////////////////////

  void _getFileGlobList(List<Glob> toList, List<String> values, {bool? isCaseSensitive, bool isTake = false}) {
    for (var value in values) {
      toList.add(Glob(value, recursive: GlobExt.isRecursive(value), caseSensitive: isCaseSensitive));
    }
    if (isTake) {
      _isTakeFileListFromStdin = _isFromStdin(values);
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  void _getFileRegexList(List<RegExp> toList, List<String> values, {bool? isCaseSensitive, bool isTake = false}) {
    for (var value in values) {
      toList.add(RegExp(Path.toPosixEscaped(value), caseSensitive: isCaseSensitive ?? !Path.isWindowsFS));
    }
    if (isTake) {
      _isTakeFileListFromStdin = _isFromStdin(values);
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  void _getTextPlainList(List<String> toList, List<String> values, {bool isCaseSensitive = false}) {
    for (var value in values) {
      toList.add((isCaseSensitive ? charSensitive : charInsensitive) + value);
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  void _getTextRegexList(List<RegExp> toList, List<String> values, {bool isCaseSensitive = false}) {
    for (var value in values) {
      toList.add(RegExp(value, caseSensitive: isCaseSensitive));
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  static bool _isFromStdin(List<String> values) =>
    ((values.length == 1) && (values[0] == StringExt.stdinPath));

  //////////////////////////////////////////////////////////////////////////////

}
