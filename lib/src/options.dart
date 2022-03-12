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

  static final Map<String, Object?> optDir = {
    'name': 'dir',
    'abbr': 'd',
    'help': 'directory to start in',
    'valueHelp': 'DIR',
    'defaultsTo': null,
  };
  static final Map<String, Object?> optPlain = {
    'name': 'plain',
    'abbr': 'p',
    'help': 'filter the content by case-sensitive plain text',
    'valueHelp': 'REGEX',
    'defaultsTo': null,
  };
  static final Map<String, Object?> optPlainNoCase = {
    'name': 'iplain',
    'abbr': 'P',
    'help': 'filter the content by case-insensitive plain text',
    'valueHelp': 'REGEX',
    'defaultsTo': null,
  };
  static final Map<String, Object?> optRegex = {
    'name': 'regex',
    'abbr': 'r',
    'help': 'filter the content by case-sensitive regular expression',
    'valueHelp': 'REGEX',
    'defaultsTo': null,
  };
  static final Map<String, Object?> optRegexNoCase = {
    'name': 'iregex',
    'abbr': 'R',
    'help': 'filter the content by case-insensitive regular expression',
    'valueHelp': 'REGEX',
    'defaultsTo': null,
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
  static final Map<String, Object?> optHelp = {
    'name': 'help',
    'abbr': 'h',
    'help': 'this help screen',
    'negatable': false,
  };
  static final Map<String, Object?> optQuiet = {
    'name': 'quiet',
    'abbr': 'q',
    'help': 'quiet mode (no output, same as verbosity 0)',
    'negatable': false,
  };
  static final Map<String, Object?> optSkip = {
    'name': 'skip',
    'abbr': 's',
    'help': 'exclude filename(s) defined by glob pattern',
    'valueHelp': 'GLOB',
    'defaultsTo': null,
  };
  static final Map<String, Object?> optSkipNoCase = {
    'name': 'iskip',
    'abbr': 'S',
    'help': 'exclude filename(s) defined by case-insensitive glob pattern',
    'valueHelp': 'GLOB',
    'defaultsTo': null,
  };
  static final Map<String, Object?> optTake = {
    'name': 'take',
    'abbr': 't',
    'help': 'include filename(s) defined by glob pattern; use "-" (dash) to get those from ${StringExt.stdinDisplay}',
    'valueHelp': 'GLOB',
    'defaultsTo': null,
  };
  static final Map<String, Object?> optTakeNoCase = {
    'name': 'itake',
    'abbr': 'T',
    'help': 'include filename(s) defined by case-insensitive glob pattern, use "-" (dash) to get those from ${StringExt.stdinDisplay}',
    'valueHelp': 'GLOB',
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

  String _plain = '';
  String get plain => _plain;

  RegExp? _regex;
  RegExp? get regex => _regex;

  bool _isPlainCaseSensitive = true;
  bool get isPlainCaseSensitive => _isPlainCaseSensitive;

  bool _isRegexCaseSensitive = true;
  bool get isRegexCaseSensitive => _isRegexCaseSensitive;

  bool _isTakeStdin = false;
  bool get isTakeStdin => _isTakeStdin;

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
      dirName = _getString(value);
    });
    addOption(parser, optPlain, (value) {
      _isPlainCaseSensitive = false;
      _plain = _getString(value);
    });
    addOption(parser, optPlainNoCase, (value) {
      _isPlainCaseSensitive = true;
      _plain = _getString(value);
    });
    addOption(parser, optRegex, (value) {
      _isRegexCaseSensitive = false;
      _regex = (value == null ? null : RegExp(value));
    });
    addOption(parser, optRegexNoCase, (value) {
      _isRegexCaseSensitive = true;
      _regex = (value == null ? null : RegExp(value));
    });
    addOption(parser, optMax, (value) {
      _max = _getInt(value, defValue: _max);
    });
    addOption(parser, optMin, (value) {
      _min = _getInt(value, defValue: _min);
    });
    addFlag(parser, optQuiet, (value) {
      if (value) {
        _logger.level = Logger.levelSilent;
      }
    });
    addOption(parser, optSkip, (value) {
      if (value != null) {
        _skip = Glob(value);
      }
    });
    addOption(parser, optSkipNoCase, (value) {
      if (value != null) {
        _skip = Glob(value, caseSensitive: false);
      }
    });
    addOption(parser, optTake, (value) {
      if (value != null) {
        _isTakeStdin = (value == StringExt.stdinPath);
        _take = (_isTakeStdin ? null : Glob(value));
      }
    });
    addOption(parser, optTakeNoCase, (value) {
      if (value != null) {
        _isTakeStdin = (value == StringExt.stdinPath);
        _take = (_isTakeStdin ? null : Glob(value, caseSensitive: false));
      }
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
        var plainArgs = result.rest;

        if (plainArgs.isNotEmpty) {
          errMsg = 'Plain arguments are not expected: $plainArgs';
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
$appName $appVersion (C) Alexander Iurovetski 2020 - 2021

A command-line utility to eXpand text content aNd to eXecute external utilities.

USAGE:

$appName [OPTIONS]

${parser.usage}

If none of -t, --take, -T, --itake options specified, read content from ${StringExt.stdinDisplay}

For more details, see README.md
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

  String _getString(String? value, {String? defValue}) =>
    value ?? defValue ?? '';

  //////////////////////////////////////////////////////////////////////////////
}
