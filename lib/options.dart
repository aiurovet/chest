// Copyright (c) 2022, Alexander Iurovetski
// All rights reserved under MIT license (see LICENSE file)

import 'dart:io';

import 'package:chest/register_services.dart';
import 'package:file/file.dart';
import 'package:glob/glob.dart';
import 'package:parse_args/parse_args.dart';
import 'package:thin_logger/thin_logger.dart';

import 'package:chest/ext/glob_ext.dart';
import 'package:chest/ext/path_ext.dart';

/// A class for command-line options
///
class Options {
  /// The application name
  ///
  static const appName = 'chest';

  /// The application version
  ///
  static const appVersion = '0.1.0';

  /// A prefix indicating the following literal match should be case-insensitive
  ///
  static const charInsensitive = 'i';

  /// A prefix indicating the following literal match should be case-sensitive
  ///
  static const charSensitive = ' ';

  /// A prefix indicating the following match (literal or regex) should be negated (made the opposite)
  ///
  static const charNeg = '!';

  /// A prefix indicating to ignore negation and treat the following character as plain
  ///
  static const charNegEscaped = '$charNeg$charNeg';

  /// A regular expression to find negations
  ///
  static final rexNeg = RegExp('^([$charNeg]+)');

  /// A regular expression to find numweric ranges as min..max
  ///
  static final rexRange = RegExp(r'\.\.+');

  //////////////////////////////////////////////////////////////////////////////

  /// A flag property indicating we fetch all files including the hidden ones
  /// (not excluding any file or sub-directory starting with the dot)
  ///
  bool get isAll => _isAll;
  var _isAll = false;

  /// A flag property indicating we just count the matches
  ///
  bool get isCount => _isCount;
  var _isCount = false;

  /// A flag property indicating we show the path in the output if applicable
  ///
  bool get isPathShown => _isPathShown;
  var _isPathShown = true;

  /// A flag property indicating we do not read or read the content
  ///
  bool get isPathsOnly => _isPathsOnly;
  var _isPathsOnly = false;

  /// A flag property indicating we get all input file paths from stdin rather than from the CLI (like xargs)
  ///
  bool get isTakeFileListFromStdin => _isTakeFileListFromStdin;
  var _isTakeFileListFromStdin = false;

  /// A numeric property for the upper limit of matches (-1 for unlimited)
  ///
  int get max => _max;
  int _max = -1;

  /// A numeric property for the lower limit of matches
  ///
  int get min => _min;
  var _min = 0;

  /// Glob patterns to filter out unwanted files
  ///
  List<Glob> get skipFileGlobList => _skipFileGlobList;
  final _skipFileGlobList = <Glob>[];

  /// Regular expression patterns to filter out unwanted files
  ///
  List<RegExp> get skipFileRegexList => _skipFileRegexList;
  final _skipFileRegexList = <RegExp>[];

  /// Literal strings to filter out unwanted lines in files or stdin
  ///
  List<String> get skipTextPlainList => _skipTextPlainList;
  final _skipTextPlainList = <String>[];

  /// Regular expression patterns to filter out unwanted lines in files or stdin
  ///
  get skipTextRegexList => _skipTextRegexList;
  final _skipTextRegexList = <RegExp>[];

  /// Glob patterns to filter in wanted files
  ///
  List<Glob> get takeFileGlobList => _takeFileGlobList;
  final List<Glob> _takeFileGlobList = [];

  /// Regular expression patterns to filter in wanted files
  ///
  List<RegExp> get takeFileRegexList => _takeFileRegexList;
  final _takeFileRegexList = <RegExp>[];

  /// Literal strings to filter in wanted lines in files or stdin
  ///
  List<String> get takeTextPlainList => _takeTextPlainList;
  final _takeTextPlainList = <String>[];

  /// Regular expression patterns to filter in wanted lines in files or stdin
  ///
  List<RegExp> get takeTextRegexList => _takeTextRegexList;
  final _takeTextRegexList = <RegExp>[];

  // Dependency injection
  //
  final _fs = services.get<FileSystem>();
  final _logger = services.get<Logger>();

  /// The constructor
  ///
  Options();

  /// The main method to parse CLI arguments
  ///
  Future parse(List<String> args) async {
    var argCount = args.length;

    if (argCount <= 0) {
      printUsage();
    }

    var dirName = '';

    var optDefs = '''
      +|?,h,help|q,quiet|v,verbose|a,all
      |d,dir:|e,exp,expect:|nocontent|nopath
      |plain::|iplain::|regex::|iregex::
      |files::|ifiles::|rfiles::|rifiles,irfiles::
    ''';

    parseArgs(optDefs, args, (isFirstRun, optName, values) {
      // Show details when not on the first run
      //
      if (!isFirstRun) {
        if (_logger.isVerbose) {
          _logger
              .verbose('Option "$optName"${values.isEmpty ? '' : ': $values'}');
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
          _logger.level = Logger.levelQuiet;
          return;
        case 'verbose':
          _logger.level = Logger.levelVerbose;
          return;

        // Directory to start in
        //
        case 'all':
          _isAll = true;
          return;

        // Directory to start in
        //
        case 'dir':
          dirName = values[0];
          return;

        // Expected range of the match count
        //
        case 'expect':
          _isCount = true;
          _parseExpectRange(values[0]);
          return;

        // Type of check
        //
        case 'nocontent':
          _isPathsOnly = true;
          return;

        // Output
        //
        case 'nopath':
          _isPathShown = false;
          return;

        // Plain skip-filters for text
        //
        case 'plain':
          _getTextPlainList(_takeTextPlainList, _skipTextPlainList, values,
              isCaseSensitive: true);
          return;
        case 'iplain':
          _getTextPlainList(_takeTextPlainList, _skipTextPlainList, values,
              isCaseSensitive: false);
          return;

        // Regex take-filters for text
        //
        case 'regex':
          _getTextRegexList(_takeTextRegexList, _skipTextRegexList, values,
              isCaseSensitive: true);
          return;
        case 'iregex':
          _getTextRegexList(_takeTextRegexList, _skipTextRegexList, values,
              isCaseSensitive: false);
          return;

        // Glob take-filters for files
        //
        case 'files':
          _getFileGlobList(_takeFileGlobList, _skipFileGlobList, values,
              dirName, isTake: true);
          return;
        case 'ifiles':
          _getFileGlobList(_takeFileGlobList, _skipFileGlobList, values,
              dirName, isTake: true, isCaseSensitive: false);
          return;

        // Regex take-filters for files
        //
        case 'rfiles':
          _getFileRegexList(_takeFileRegexList, _skipFileRegexList, values,
              isTake: true);
          return;
        case 'irfiles':
          _getFileRegexList(_takeFileRegexList, _skipFileRegexList, values,
              isTake: true, isCaseSensitive: false);
          return;
      }
    });

    // Post-parsing
    //
    await setCurrentDirectory(dirName);
  }

  /// Show how to use the application
  ///
  Never printUsage([String? error]) {
    _logger.error('''
$appName $appVersion (c) 2022 Alexander Iurovetski

Check Strings: a command-line utility to read text from files or stdin and
filter the content based on plain text or regular expression, then, optionally,
check that the number of matching lines is within the specified range

USAGE:

$appName [OPTIONS]

-?,-h[elp]        - this help screen
-q[uiet]          - no output
-v[erbose]        - detailed output
-a[ll]            - scan all files including the hidden ones
                    (a filename or a sub-dir of any level starting with '.')
-d[ir]      DIR   - directory to start in
-e[xp[ect]] RANGE - expected minimum number of matching lines:
                    3 (exact), 2..5 (2 to 5), 2.. (2 or more), ..5 (up to 5)
-plain      TEXT  - filter lines matching or not matching plain text,
                    case-sensitive
-iplain     TEXT  - filter lines matching or not matching plain text,
                    case-insensitive
-regex      REGEX - filter lines matching or not matching regex,
                    case-sensitive
-iregex     REGEX - filter lines matching or not matching regex,
                    case-insensitive
-files      GLOB  - include or exclude filename(s) defined by glob,
                    case-OS-specific
-ifiles     GLOB  - include or exclude filename(s) defined by glob,
                    case-insensitive
-rfiles     REGEX - include or exclude filename(s) defined by regex,
                    case-OS-specific
-irfiles    REGEX - include or exclude filename(s) defined by regex,
                    case-insensitive

Option names are case-insensitive and dash-insensitive: you can use any
number of dashes in the front, in the middle or at the back of any option
name.

If the value of any of -[i]files is '-', read the list of files from stdin.
If none of -[ir]files specified, read and filter text from stdin.

If the value of any of -[i]rfiles does not contain '/', it will be matched
against the filenames rather than paths. All directory separators will be
converted to POSIX-compliant '/' before undertaking the match.

Negation (the opposite match) is achieved by prepending a pattern or a plain
text with an exclamation mark '!'. It can be escaped by doubling that: '!!'.

EXAMPLES:

$appName -dir "\${HOME}/Documents" -files '**' "!*.doc*"
$appName -dir "%{USERPROFILE}%\\Documents" -files '**' "!*.doc*"

$appName -d "\${HOME}/Projects/chest/app" -ifiles '**.{gz,zip}' -e 3 -nocontent
''');

    if (error != null) {
      throw Exception(error);
    }

    exit(1);
  }

  /// Make directory, passed as CLI option, the current one
  ///
  Future setCurrentDirectory(String? dirName) async {
    if (_logger.isVerbose) {
      _logger.verbose(
          'Arg start dir: ${dirName == null ? '<unknown>' : '"$dirName"'}\n');
    }

    if (dirName?.isEmpty ?? false) {
      return;
    }

    var dir = _fs.directory(_fs.path.adjust(dirName));

    if (!await dir.exists()) {
      throw Exception('Directory is not found: "$dirName"');
    }

    _fs.currentDirectory = dir;

    if (_logger.isVerbose) {
      _logger.verbose('Switching to dir: "$dirName"\n');
    }
  }

  /// A helper to get a take- or skip- glob pattern list for input file paths from CLI arguments
  ///
  void _getFileGlobList(List<Glob> toList, List<Glob> toNegList, List values,
      String topDirName, {bool? isCaseSensitive, bool isTake = false}) {
    for (var value in values) {
      var fullValue = _fs.path.getFullPath(_fs.path.join(topDirName, value));
      var info = _getNegInfo(toList, toNegList, fullValue);

      info[0].add(Glob(info[1],
          recursive: GlobExt.isRecursive(info[1]),
          caseSensitive: isCaseSensitive));
    }
    if (isTake) {
      _isTakeFileListFromStdin = _isFromStdin(values);
    }
  }

  /// A helper to get a take- or skip- regular expression pattern list for input file paths from CLI arguments
  ///
  void _getFileRegexList(
      List<RegExp> toList, List<RegExp> toNegList, List values,
      {bool? isCaseSensitive, bool isTake = false}) {
    for (var value in values) {
      var info = _getNegInfo(toList, toNegList, value);
      info[0].add(RegExp(_fs.path.toPosix(info[1], isEscaped: true),
          caseSensitive: isCaseSensitive ?? _fs.path.isCaseSensitive));
    }
    if (isTake) {
      _isTakeFileListFromStdin = _isFromStdin(values);
    }
  }

  /// A helper to get negation info: a parser for leading exclamation mark
  ///
  List _getNegInfo(List toList, List toNegList, String value) {
    var negPrefix = rexNeg.firstMatch(value)?.group(1) ?? '';
    var negLen = negPrefix.length;

    return [
      ((negLen % 2) == 1 ? toNegList : toList),
      value.substring(negLen),
    ];
  }

  /// A helper to get a take- or skip- sub-string list for content lines from CLI arguments
  ///
  void _getTextPlainList(
      List<String> toList, List<String> toNegList, List values,
      {bool isCaseSensitive = false}) {
    for (var value in values) {
      var info = _getNegInfo(toList, toNegList, value);
      var prefix = (isCaseSensitive ? charSensitive : charInsensitive);
      info[0].add(prefix + info[1]);
    }
  }

  /// A helper to get a take- or skip- regular expression pattern list for content lines from CLI arguments
  ///
  void _getTextRegexList(
      List<RegExp> toList, List<RegExp> toNegList, List values,
      {bool isCaseSensitive = false}) {
    for (var value in values) {
      var info = _getNegInfo(toList, toNegList, value);
      info[0].add(RegExp(info[1], caseSensitive: isCaseSensitive));
    }
  }

  /// A helper to determine whether the file list represents a plain stdin
  ///
  static bool _isFromStdin(List values) =>
      ((values.length == 1) && (values[0] == '-'));

  /// A helper to parse a string [value] into lower and upper boundary ints
  ///
  void _parseExpectRange(String value) {
    var matchSep = rexRange.firstMatch(value);

    if (matchSep == null) {
      _min = int.parse(value);
      _max = _min;
    } else {
      _min = (matchSep.start == 0
          ? 0
          : int.parse(value.substring(0, matchSep.start)));
      _max = (matchSep.end == value.length
          ? -1
          : int.parse(value.substring(matchSep.end)));
    }
  }
}
