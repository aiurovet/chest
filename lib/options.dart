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

  static const String charInsensitive = 'i';
  static const String charSensitive = ' ';

  static const String charNeg = '!';
  static const String charNegEscaped = '$charNeg$charNeg';

  static final RegExp rexNeg = RegExp('^([$charNeg]+)');

  //////////////////////////////////////////////////////////////////////////////

  get isCount => _isCount;
  var _isCount = false;

  get isPathsOnly => _isPathsOnly;
  var _isPathsOnly = false;

  get isTakeFileListFromStdin => _isTakeFileListFromStdin;
  var _isTakeFileListFromStdin = false;

  int get max => _max;
  int _max = -1;

  int get min => _min;
  int _min = 0;

  get skipFileGlobList => _skipFileGlobList;
  final _skipFileGlobList = <Glob>[];

  get skipFileRegexList => _skipFileRegexList;
  final _skipFileRegexList = <RegExp>[];

  get skipTextPlainList => _skipTextPlainList;
  final _skipTextPlainList = <String>[];

  get skipTextRegexList => _skipTextRegexList;
  final _skipTextRegexList = <RegExp>[];

  get takeFileGlobList => _takeFileGlobList;
  final _takeFileGlobList = <Glob>[];

  get takeFileRegexList => _takeFileRegexList;
  final _takeFileRegexList = <RegExp>[];

  get takeTextPlainList => _takeTextPlainList;
  final _takeTextPlainList = <String>[];

  get takeTextRegexList => _takeTextRegexList;
  final _takeTextRegexList = <RegExp>[];

  //////////////////////////////////////////////////////////////////////////////

  Logger _logger = Logger();

  //////////////////////////////////////////////////////////////////////////////

  Options([Logger? log]) {
    if (log != null) {
      _logger = log;
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  Future parse(List<String> args) async {
    var argCount = args.length;

    if (argCount <= 0) {
      printUsage();
    }

    var dirName = '';

    var optDefs = '''
      +|?,h,help|quiet|verbose|d,dir:|equ:i|max:i|min:i|nocontent|text::|itext::
       |regex::|iregex::|files::|ifiles::|rfiles::|rifiles,irfiles::''';

    parseArgs(optDefs, args, (isFirstRun, optName, values) {
      // Show details when not on the first run
      //
      if (!isFirstRun) {
        if (_logger.isDebug) {
          _logger.debug('Option "$optName"${values.isEmpty ? '' : ': $values'}');
        }
        return;
      }

      // Assign option values
      //
      switch (optName) {
        case 'help':
          printUsage();

        // Logging flags
        //
        case 'quiet':
          _logger.level = Logger.levelSilent;
          return;
        case 'verbose':
          _logger.level = Logger.levelDebug;
          return;

        // Directory to start in
        //
        case 'dir':
          dirName = values[0];
          return;

        // Expected match count boundaries
        //
        case 'equ':
          _isCount = true;
          _max = values[0];
          _min = _max;
          return;
        case 'max':
          _isCount = true;
          _max = values[0];
          return;
        case 'min':
          _isCount = true;
          _min = values[0];
          return;

        // Type of check
        //
        case 'nocontent':
          _isPathsOnly = true;
          return;

        // Plain skip-filters for text
        //
        case 'text':
          _getTextPlainList(_takeTextPlainList, _skipTextPlainList, values, isCaseSensitive: true);
          return;
        case 'itext':
          _getTextPlainList(_takeTextPlainList, _skipTextPlainList, values, isCaseSensitive: false);
          return;

        // Regex take-filters for text
        //
        case 'regex':
          _getTextRegexList(_takeTextRegexList, _skipTextRegexList, values, isCaseSensitive: true);
          return;
        case 'iregex':
          _getTextRegexList(_takeTextRegexList, _skipTextRegexList, values, isCaseSensitive: false);
          return;

        // Glob take-filters for files
        //
        case 'files':
          _getFileGlobList(_takeFileGlobList, _skipFileGlobList, values, isTake: true);
          return;
        case 'ifiles':
          _getFileGlobList(_takeFileGlobList, _skipFileGlobList, values, isTake: true, isCaseSensitive: false);
          return;

        // Regex take-filters for files
        //
        case 'rfiles':
          _getFileRegexList(_takeFileRegexList, _skipFileRegexList, values, isTake: true);
          return;
        case 'irfiles':
          _getFileRegexList(_takeFileRegexList, _skipFileRegexList, values, isTake: true, isCaseSensitive: false);
          return;
      }
    });

    // Post-parsing

    await setCurrentDirectory(dirName);
  }

  //////////////////////////////////////////////////////////////////////////////

  Never printUsage([String? error]) {
    _logger.error('''
$appName $appVersion (c) 2022 Alexander Iurovetski

Check Strings: a command-line utility to read text from files or stdin and
filter the content based on plain text or regular expression, then, optionally,
check that the number of matching lines is within the specified range

USAGE:

$appName [OPTIONS]

-[-]help, -?, -h    - this help screen
-[-]quiet           - no output
-[-]verbose         - detailed output
-[-]dir     <DIR>   - directory to start in
-[-]equ     <INT>   - expected exact number of matching lines
-[-]min     <INT>   - expected minimum number of matching lines
-[-]max     <INT>   - expected maximum number of matching lines
-[-]plain   <TEXT>  - filter lines matching or not matching plain text,
                      case-sensitive
-[-]iplain  <TEXT>  - filter lines matching or not matching plain text,
                      case-insensitive
-[-]regex   <REGEX> - filter lines matching or not matching regex,
                      case-sensitive
-[-]iregex  <REGEX> - filter lines matching or not matching regex,
                      case-insensitive
-[-]files   <GLOB>  - include or exclude filename(s) defined by glob,
                      case-OS-specific
-[-]ifiles  <GLOB>  - include or exclude filename(s) defined by glob,
                      case-insensitive

If the value of any of -[i]files is '-', read the list of files from stdin.
If none of -[ir]files specified, read and filter text from stdin.

Negation (not matching) is achieved by prepending a pattern or a plain text
with an exclamation mark '!'. It can be escaped by doubling that: '!!'.
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

  void _getFileGlobList(List<Glob> toList, List<Glob> toNegList, List values, {bool? isCaseSensitive, bool isTake = false}) {
    for (var value in values) {
      var info = _getNegInfo(toList, toNegList, value);
      info[0].add(Glob(info[1], recursive: GlobExt.isRecursive(info[1]), caseSensitive: isCaseSensitive));
    }
    if (isTake) {
      _isTakeFileListFromStdin = _isFromStdin(values);
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  void _getFileRegexList(List<RegExp> toList, List<RegExp> toNegList, List values, {bool? isCaseSensitive, bool isTake = false}) {
    for (var value in values) {
      var info = _getNegInfo(toList, toNegList, value);
      info[0].add(RegExp(Path.toPosixEscaped(info[1]), caseSensitive: isCaseSensitive ?? !Path.isWindowsFS));
    }
    if (isTake) {
      _isTakeFileListFromStdin = _isFromStdin(values);
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  List _getNegInfo(List toList, List toNegList, String value) {
    var negPrefix = rexNeg.firstMatch(value)?.group(1) ?? '';
    var negLen = negPrefix.length;

    return [
      ((negLen % 2) == 1 ? toNegList : toList),
      value.substring(negLen),
    ];
  }

  //////////////////////////////////////////////////////////////////////////////

  void _getTextPlainList(List<String> toList, List<String> toNegList, List values, {bool isCaseSensitive = false}) {
    for (var value in values) {
      var info = _getNegInfo(toList, toNegList, value);
      info[0].add((isCaseSensitive ? charSensitive : charInsensitive) + info[1]);
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  void _getTextRegexList(List<RegExp> toList, List<RegExp> toNegList, List values, {bool isCaseSensitive = false}) {
    for (var value in values) {
      var info = _getNegInfo(toList, toNegList, value);
      info[0].add(RegExp(info[1], caseSensitive: isCaseSensitive));
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  static bool _isFromStdin(List values) =>
    ((values.length == 1) && (values[0] == StringExt.stdinPath));

  //////////////////////////////////////////////////////////////////////////////

}
