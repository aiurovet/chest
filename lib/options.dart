// Copyright (c) 2022-2023, Alexander Iurovetski
// All rights reserved under MIT license (see LICENSE file)
//
import 'dart:io';

import 'package:chest/chest_pattern.dart';
import 'package:chest/printer.dart';
import 'package:chest/register_services.dart';
import 'package:glob/glob.dart';
import 'package:parse_args/parse_args.dart';
import 'package:thin_logger/thin_logger.dart';

/// A class for command-line options
///
class Options {
  /// Const: application name
  ///
  static const appName = 'chest';

  /// Const: application version
  ///
  static const appVersion = '0.1.0';

  //////////////////////////////////////////////////////////////////////////////

  /// Glob patterns to filter files
  ///
  List<Glob> get globs => _globs;
  final List<Glob> _globs = [];

  /// Flag indicating there is at least one case-insensitive pattern
  ///
  bool get hasCaseInsensitive => _hasCaseInsensitive;
  var _hasCaseInsensitive = false;

  /// Flag indicating there is at least one case-insensitive pattern
  ///
  bool get hasPlain => _hasPlain;
  var _hasPlain = false;

  /// Flag indicating we just count the matches
  ///
  bool get isCount => _isCount;
  var _isCount = false;

  /// Flag indicating we do not read the content
  ///
  bool get isContent => _isContent;
  var _isContent = false;

  /// Flag indicating we fetch all files including the hidden ones
  /// (not excluding any file or sub-directory starting with the dot)
  ///
  bool get isHiddenAllowed => _isHiddenAllowed;
  var _isHiddenAllowed = false;

  /// Flag indicating multi-line text match
  ///
  bool get isMultiLine => _isMultiLine;
  var _isMultiLine = false;

  /// Flag indicating the stdin contains paths to files to be processed
  ///
  bool get isXargs => _isXargs;
  var _isXargs = false;

  /// Numeric property for the upper limit of matches (-1 for unlimited)
  ///
  int get max => _max;
  int _max = -1;

  /// A numeric property for the lower limit of matches
  ///
  int get min => _min;
  var _min = 0;

  /// Patterns to find
  ///
  List<List<ChestPattern>> get patterns => _patterns;
  final _patterns = <List<ChestPattern>>[];

  /// Output object
  ///
  Printer get printer => _printer;
  late final Printer _printer;

  /// Root names (base directories) to filter by [patterns])
  ///
  List<String> get roots => _roots;
  final List<String> _roots = [];

  // Dependency injection
  //
  final _logger = services.get<Logger>();

  /// The constructor
  ///
  Options();

  /// The main method to parse CLI arguments
  ///
  Future parse(List<String> args) async {
    var subFlags = 'i,icase,and,or,not';

    var optDefStr = '''
      |?,h,help|q,quiet|v,verbose|a,all
      |c,count|d,dir::|e,exp,expect:,:
      |m,multi,multiline|n,nocontent
      |o,out,format:|f,file,files::
      |p,plain::>$subFlags,r,regex
      |r,regex::>$subFlags,p,plain
      |x,xargs
    ''';

    var opts = parseArgs(optDefStr, args);

    _logger.levelFromFlags(
        isQuiet: opts.isSet('q'), isVerbose: opts.isSet('v'));

    if (args.isEmpty || opts.isSet('?')) {
      printUsage();
    }

    _isHiddenAllowed = opts.isSet('a');
    _roots.addAll(opts.getStrValues('d'));

    _setExpectAndIsCount(opts.getStrValues('e'), opts.isSet('c'));

    _globs.addAll(opts.getGlobValues('f'));
    _isMultiLine = opts.isSet('m');
    _isContent = !opts.isSet('n');
    _setPrinter(opts.getStrValue('o'));
    _isXargs = opts.isSet('x');
    _setPatterns(opts.getStrValues('p'), opts.getStrValues('r'));
  }

  /// Get min and max count expected
  ///
  void _setExpectAndIsCount(List<String> expect, bool isCount) {
    if (expect.isEmpty) {
      _isCount = isCount;
      _min = -1;
      _max = -1;
    } else {
      _isCount = true;
      _min = int.tryParse(expect[0]) ?? 0;
      _max = int.tryParse(expect[expect.length - 1]) ?? -1;
    }
  }

  /// Get min and max count expected
  ///
  void _setPrinter(String? format) {
    if (_isCount && ((format == null) || format.isEmpty)) {
      format = Printer.getDefaultFormatForCount();
    }

    _printer = Printer(format);
  }

  /// Create and assign plain (non-regex) patterns
  ///
  void _setPatterns(List<String> plainPatterns, List<String> regexPatterns) {
    var isCaseSensitive = true;
    var isNegative = false;
    var isRegular = false;
    var patternList = <ChestPattern>[];

    var values = <String>[...plainPatterns, ...regexPatterns];
    var patternNo = -1;
    var plainCount = plainPatterns.length;

    for (var value in values) {
      if ((++patternNo) == plainCount) {
        isRegular = true;
      }
      switch (value) {
        case '-i':
        case '-icase':
          isCaseSensitive = false;
          _hasCaseInsensitive = true;
          continue;
        case '+i':
        case '+icase':
          isCaseSensitive = true;
          continue;
        case '-and':
        case '+and':
          continue;
        case '-not':
          isNegative = true;
          continue;
        case '+not':
          isNegative = false;
          continue;
        case '-or':
          if (patternList.isNotEmpty) {
            _patterns.add(patternList);
            patternList = <ChestPattern>[];
          }
          continue;
        case '+or':
          continue;
        case '-p':
        case '-plain':
          isRegular = false;
          continue;
        case '+p':
        case '+plain':
          isRegular = true;
          continue;
        case '-r':
        case '-regex':
          isRegular = true;
          continue;
        case '+r':
        case '+regex':
          isRegular = false;
          continue;
        default:
          if (value.isEmpty) {
            continue;
          }
          break;
      }

      if (!_isMultiLine && !isRegular) {
        _hasPlain = true;
      }

      _addPattern(patternList, value,
          caseSensitive: isCaseSensitive,
          multiLine: _isMultiLine,
          negative: isNegative,
          regular: isRegular);

      isNegative = false;
    }

    if (patternList.isNotEmpty) {
      _patterns.add(patternList);
    }
  }

  /// Show how to use the application
  ///
  Never printUsage([String? error]) {
    _logger.error('''
$appName $appVersion (c) 2022-2023 Alexander Iurovetski

CHEck STrings: command-line utility to read text from files or stdin or from
files listed in stdin, then to filter the content. Filtration is based on plain
(literal) text strings and/or regular expressions (can be linked to each other
by logical operators). The result can be checked upon the number of matches
being within the expected range.

USAGE:

$appName [OPTIONS]

-?,-h[elp]         - this help screen

-q[uiet]           - no output

-v[erbose]         - detailed output

-a[ll]             - scan all files including the hidden ones
                     (when a filename starts with '.')

-c[ount]           - show the number of matched lines or blocks (for the
                     multi-line match) rather than the actual text;
                     will be turned on if -e[xp[ect]] is specified

-d[ir] DIRs        - one or more directories as bases to resolve GLOBs with
                     (relative) sub-directories; see -f[iles]

-e[xp[ect]] RANGE  - expected RANGE for the number of matching lines
                     or blocks (turns -c[ount] on):
                     3   - exactly 3
                     2,5 - between 2 and 5
                     2,  - 2 or more
                     ,5  - up to 5

-m[ulti[[-]line]]  - multi-line search: applies to all patterns and converts
                     plain pattern into a regex, spaces are converted to the
                     'any number of whitespaces' pattern: [\\s]+

-n[o[-]content]    - perform filtering on file paths or names
                     rather than those content

-o[ut],-format FMT - output format, the following placeholders accepted:
                     c  - number of matching lines or blocks
                     l  - sequential line number
                     f  - file name
                     p  - file path
                     s  - text (content) of the matched line(s)
                     \\t - tab character
                     \\n - line-break character

                     in order to use brackets, pipes, tabs or line-breaks, you
                     need to wrap FMT in single or double quotes as follows:
                     'p|m\\n' or "p (l)\\ts\\n";

                     if none of the placeholders specified, FMT will be treated
                     as a field separator in default format)

-p[lain] TEXTs     - filter lines matching or not matching plain one or more
                     text (literal) case-sensitive patterns, has sub-options:
                     -i[case] - ignore case (case-insensitive on)
                     +i[case] - exact (case-insensitive off)
                     -and     - match prev pattern AND this one
                     -not     - next pattern should NOT be found
                     -or      - match prev patterns OR this one
                     -r[egex] - switch to -regex

-r[egex] REGEXes   - similar to -plain, but using regular expression patterns
                     rather than plain text strings, has a sub-option -p[lain]
                     to switch back to plain text (literal)

-f[ile[s]] GLOBs   - one or more glob patterns as separate arguments,
                     case-insensitive for Windows, and case-sensitive
                     for POSIX-compliant file systems (Linux, macOS)

-x[args]           - similar to -f[iles], but takes glob patterns from stdin
                     (one per line) rather than from the command-line arguments;
                     in this case, -f[iles] ignored

Option names are case-insensitive and dash-insensitive: you can use
any number of dashes in the front, in the middle or at the back of
any option name.

EXAMPLES:

$appName -dir "\${HOME}/Documents" -files '**' "../*.csv" -plain -not ","
$appName -d "\${HOME}/Projects/chest/app" -files '**.{gz,zip}' -e 3 -o "c:p"
''');

    if (error != null) {
      throw Exception(error);
    }

    exit(1);
  }

  /// Add pattern to pattern list
  ///
  static void _addPattern(List<ChestPattern> to, String value,
      {bool caseSensitive = true,
      bool multiLine = false,
      bool negative = false,
      bool regular = false}) {
    if (multiLine && !regular) {
      to.add(ChestPattern(RegExp.escape(value).replaceAll(' ', r'[\s]*'),
          caseSensitive: caseSensitive,
          negative: negative,
          multiLine: multiLine,
          regular: true));
    } else {
      to.add(ChestPattern(value,
          caseSensitive: caseSensitive, negative: negative, regular: regular));
    }
  }
}
