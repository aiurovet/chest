import 'dart:io';

import 'package:args/args.dart';
import 'package:glob/glob.dart';

import 'package:chest/src/ext/path.dart';
import 'package:chest/src/ext/string.dart';
import 'package:chest/src/logger.dart';

class Options {

  //////////////////////////////////////////////////////////////////////////////

  static const String appName = 'chest';
  static const String appVersion = '0.1.0';
  static const String helpMin = '-?';

  //////////////////////////////////////////////////////////////////////////////

  static final _emptyRegex = RegExp('');

  //////////////////////////////////////////////////////////////////////////////

  static final Map<String, Object?> optDir = {
    'name': 'dir',
    'abbr': 'd',
    'help': 'directory to start in',
    'valueHelp': 'DIR',
    'defaultsTo': null,
  };
  static final Map<String, Object?> optHelp = {
    'name': 'help',
    'abbr': 'h',
    'help': 'this help screen',
    'negatable': false,
  };
  static final Map<String, Object?> optMax = {
    'name': 'max',
    'abbr': 'M',
    'help': 'maximum expected number of matching lines',
    'valueHelp': 'INT',
    'defaultsTo': null,
  };
  static final Map<String, Object?> optMin = {
    'name': 'min',
    'abbr': 'm',
    'help': 'minimum expected number of matching lines',
    'valueHelp': 'INT',
    'defaultsTo': null,
  };
  static final Map<String, Object?> optTakeTextPlain = {
    'name': 'plain',
    'abbr': 'p',
    'help': 'print lines matching plain text, case-sensitive',
    'valueHelp': 'TEXT',
    'defaultsTo': null,
  };
  static final Map<String, Object?> optTakeTextPlainNoCase = {
    'name': 'iplain',
    'abbr': 'P',
    'help': 'print lines matching plain text, case-insensitive',
    'valueHelp': 'TEXT',
    'defaultsTo': null,
  };
  static final Map<String, Object?> optQuiet = {
    'name': 'quiet',
    'abbr': 'q',
    'help': 'quiet mode (no output, same as verbosity 0 or quiet)',
    'negatable': false,
  };
  static final Map<String, Object?> optSkipFileGlob = {
    'name': 'skip',
    'abbr': 's',
    'help': 'exclude filename(s) defined by glob pattern',
    'valueHelp': 'GLOB',
    'defaultsTo': null,
  };
  static final Map<String, Object?> optSkipFileGlobNoCase = {
    'name': 'iskip',
    'abbr': 'S',
    'help': 'exclude filename(s) defined by case-insensitive glob pattern',
    'valueHelp': 'GLOB',
    'defaultsTo': null,
  };
  static final Map<String, Object?> optSkipTextPlain = {
    'name': 'noplain',
    'abbr': 'a',
    'help': 'print lines not matching plain text, case-sensitive',
    'valueHelp': 'TEXT',
    'defaultsTo': null,
  };
  static final Map<String, Object?> optSkipTextPlainNoCase = {
    'name': 'inoplain',
    'abbr': 'A',
    'help': 'print lines not matching plain text, case-insensitive',
    'valueHelp': 'TEXT',
    'defaultsTo': null,
  };
  static final Map<String, Object?> optSkipTextPlainNoCase2 = {
    'name': 'noiplain',
    'help': 'same as inoplain',
    'valueHelp': 'TEXT',
    'defaultsTo': null,
  };
  static final Map<String, Object?> optSkipTextRegex = {
    'name': 'noregex',
    'abbr': 'n',
    'help': 'print lines not matching regex, case-sensitive',
    'valueHelp': 'REGEX',
    'defaultsTo': null,
  };
  static final Map<String, Object?> optSkipTextRegexNoCase = {
    'name': 'inoregex',
    'abbr': 'N',
    'help': 'print lines not matching regex, case-insensitive',
    'valueHelp': 'REGEX',
    'defaultsTo': null,
  };
  static final Map<String, Object?> optSkipTextRegexNoCase2 = {
    'name': 'noiregex',
    'help': 'same as inoregex',
    'valueHelp': 'REGEX',
    'defaultsTo': null,
  };
  static final Map<String, Object?> optTakeFileGlob = {
    'name': 'take',
    'abbr': 't',
    'help': 'include filename(s) defined by glob pattern',
    'valueHelp': 'GLOB',
    'defaultsTo': null,
  };
  static final Map<String, Object?> optTakeFileGlobNoCase = {
    'name': 'itake',
    'abbr': 'T',
    'help': 'include filename(s) defined by case-insensitive glob pattern',
    'valueHelp': 'GLOB',
    'defaultsTo': null,
  };
  static final Map<String, Object?> optTakeTextRegex = {
    'name': 'regex',
    'abbr': 'r',
    'help': 'print lines matching regex, case-sensitive',
    'valueHelp': 'REGEX',
    'defaultsTo': null,
  };
  static final Map<String, Object?> optTakeTextRegexNoCase = {
    'name': 'iregex',
    'abbr': 'R',
    'help': 'print lines matching regex, case-insensitive',
    'valueHelp': 'REGEX',
    'defaultsTo': null,
  };
  static final Map<String, Object?> optVerbosity = {
    'name': 'verbosity',
    'abbr': 'v',
    'help': '''how much information to show: (0-6, or: quiet, errors, normal, warnings, info, debug),
defaults to "${Logger.levels[Logger.levelDefault]}"''',
    'valueHelp': 'LEVEL',
    'defaultsTo': null,
  };

  //////////////////////////////////////////////////////////////////////////////

  static const String charInsensitive = 'i';
  static const String charSensitive = ' ';

  String _skipTextPlain = '';
  String get skipTextPlain => _skipTextPlain;

  RegExp _skipTextRegex = _emptyRegex;
  RegExp get skipTextRegex => _skipTextRegex;

  String _takeTextPlain = '';
  String get takeTextPlain => _takeTextPlain;

  RegExp _takeTextRegex = _emptyRegex;
  RegExp get takeTextRegex => _takeTextRegex;

  bool _isTakeFilesFromStdin = false;
  bool get isTakeFilesFromStdin => _isTakeFilesFromStdin;

  int _max = -1;
  int get max => _max;

  int _min = 0;
  int get min => _min;

  Glob? _skip;
  Glob? get skip => _skip;

  Glob? _take;
  Glob? get take => _take;

  //////////////////////////////////////////////////////////////////////////////

  Logger _logger = Logger();

  //////////////////////////////////////////////////////////////////////////////

  Options([Logger? log]) {
    if (log != null) {
      _logger = log;
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  static void addFlag(ArgParser parser, Map<String, Object?> option, void Function(bool)? callback) {
    parser.addFlag(
      option['name']?.toString() ?? '',
      abbr: option['abbr']?.toString(),
      help: option['help']?.toString(),
      negatable: (option['negatable'] as bool?) ?? false,
      callback: callback
    );
  }

  //////////////////////////////////////////////////////////////////////////////

  static void addOption(ArgParser parser, Map<String, Object?> option, void Function(String?)? callback) {
    parser.addOption(
      option['name']?.toString() ?? '',
      abbr: option['abbr']?.toString(),
      help: option['help']?.toString(),
      valueHelp: option['valueHelp']?.toString(),
      defaultsTo: option['defaultsTo']?.toString(),
      callback: callback
    );
  }

  //////////////////////////////////////////////////////////////////////////////

  static void addOptions(ArgParser parser, Map<String, Object?> option1, Map<String, Object?> option2, void Function(String?)? callback) {
    addOption(parser, option1, callback);

    if (option2 != option1) {
      addOption(parser, option2, callback);
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  void parseArgs(List<String> args) {
    var dirName = '';
    var errMsg = '';
    var isHelp = false;

    final parser = ArgParser();

    addFlag(parser, optHelp, (value) {
      if (value) {
        isHelp = true;
      }
    });
    addOption(parser, optDir, (value) {
      if (value != null) {
        dirName = _getString(value);
      }
    });
    addOption(parser, optMin, (value) {
      _min = _getInt(value, defValue: _min);
    });
    addOption(parser, optMax, (value) {
      _max = _getInt(value, defValue: _max);
    });
    addFlag(parser, optQuiet, (value) {
      if (value) {
        _logger.level = Logger.levelSilent;
      }
    });
    addOption(parser, optTakeFileGlob, (value) {
      _isTakeFilesFromStdin = (value == StringExt.stdinPath);
      _take = (_isTakeFilesFromStdin || (value == null) ? null : Glob(value));
    });
    addOption(parser, optTakeFileGlobNoCase, (value) {
      _isTakeFilesFromStdin = (value == StringExt.stdinPath);
      _take = (_isTakeFilesFromStdin || (value == null) ? null : Glob(value, caseSensitive: false));
    });
    addOption(parser, optSkipFileGlob, (value) {
      _skip = (value == null ? null : Glob(value));
    });
    addOption(parser, optSkipFileGlobNoCase, (value) {
      _skip = (value == null ? null : Glob(value, caseSensitive: false));
    });
    addOption(parser, optTakeTextPlain, (value) {
      _takeTextPlain = _getString(value, isCaseSensitive: true);
    });
    addOption(parser, optTakeTextPlainNoCase, (value) {
      _takeTextPlain = _getString(value, isCaseSensitive: false).toLowerCase();
    });
    addOption(parser, optTakeTextRegex, (value) {
      _takeTextRegex = (value == null ? _emptyRegex : RegExp(value, caseSensitive: true));
    });
    addOption(parser, optTakeTextRegexNoCase, (value) {
      _takeTextRegex = (value == null ? _emptyRegex : RegExp(value, caseSensitive: false));
    });
    addOption(parser, optSkipTextPlain, (value) {
      _skipTextPlain = _getString(value, isCaseSensitive: true);
    });
    addOptions(parser, optSkipTextPlainNoCase, optSkipTextPlainNoCase2, (value) {
      _skipTextPlain = _getString(value, isCaseSensitive: false).toLowerCase();
    });
    addOption(parser, optSkipTextRegex, (value) {
      _skipTextRegex = (value == null ? _emptyRegex : RegExp(value, caseSensitive: true));
    });
    addOptions(parser, optSkipTextRegexNoCase, optSkipTextRegexNoCase2, (value) {
      _skipTextRegex = (value == null ? _emptyRegex : RegExp(value, caseSensitive: false));
    });
    addOption(parser, optVerbosity, (value) {
      if (value != null) {
        _logger.levelAsString = _getString(value);
      }
    });

    if (!_logger.hasLevel) {
      _logger.level = Logger.levelDefault;
    }

    if (args.isEmpty || args.contains(helpMin)) {
      printUsage(parser);
    }

    try {
      var result = parser.parse(args);

      if (!isHelp) {
        var rest = result.rest;

        if (rest.isNotEmpty) {
          errMsg = 'Plain arguments are not expected: $rest';
          isHelp = true;
        }

        setCurrentDirectory(dirName);
      }
    }
    catch (e) {
      errMsg = (isHelp ? '' : e.toString());
      isHelp = true;
    }

    if (isHelp) {
      printUsage(parser, error: errMsg);
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  void printUsage(ArgParser parser, {String? error}) {
    if (!_logger.isSilent) {
      stderr.writeln('''
$appName $appVersion (c) Alexander Iurovetski 2022

Check Strings: a command-line utility to read text from files or ${StringExt.stdinDisplay} and filter the content based on plain text or regular expression, then, optionally, check that the number of matching lines is within the specified range

USAGE:

$appName [OPTIONS]

${parser.usage}

If the value of -t/--take or -T/--itake option is ${StringExt.stdinPath}, treat ${StringExt.stdinDisplay} as the list of files to process
If neither -t/--take nor -T/--itake option specified, read and filter text from ${StringExt.stdinDisplay}
'''
      );
    }

    throw Exception(error?.isBlank() ?? true ? optHelp['name'] ?? '' : error);
  }

  //////////////////////////////////////////////////////////////////////////////

  void setCurrentDirectory(String? dirName) {
    if (_logger.isDebug) {
      _logger.debug('Arg start dir: ${dirName == null ? StringExt.unknown : '"$dirName"'}\n');
    }

    if ((dirName == null) || dirName.isBlank()) {
      dirName = Path.currentDirectory.path;
    }
    else {
      var dir = Path.fileSystem.directory(dirName);

      if (!dir.existsSync()) {
        throw Exception('Directory is not found: "$dirName"');
      }

      Path.currentDirectory = dir;

      if (_logger.isDebug) {
        _logger.debug('Switching to dir: "$dirName"\n');
      }
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  int _getInt(String? value, {int defValue = 0}) =>
    (int.tryParse(_getString(value)) ?? defValue);

  //////////////////////////////////////////////////////////////////////////////

  String _getString(String? value, {bool? isCaseSensitive, String? defValue}) =>
    (isCaseSensitive == null ? '' : isCaseSensitive ? ' ' : 'i') + (value ?? defValue ?? '');

  //////////////////////////////////////////////////////////////////////////////
}
