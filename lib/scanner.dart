import 'dart:convert';
import 'dart:io';
import 'package:chest/ext/glob.dart';
import 'package:chest/ext/string.dart';
import 'package:chest/logger.dart';
import 'package:chest/ext/path.dart';
import 'package:chest/options.dart';
import 'package:glob/glob.dart';

class Scanner {

  //////////////////////////////////////////////////////////////////////////////

  final Options options;
  final Logger logger;

  //////////////////////////////////////////////////////////////////////////////

  int count = 0;
  final _lineSplitter = LineSplitter();

  //////////////////////////////////////////////////////////////////////////////

  Scanner(this.options, this.logger);

  //////////////////////////////////////////////////////////////////////////////

  Future exec() async {
    if (options.isTakeFileListFromStdin) {
      await execEachFileFromStdin();
    }
    else if (options.takeFileGlobList.isEmpty && options.takeFileRegexList.isEmpty) {
      execContentFromStdin();
    }
    else {
      await execEachFileFromGlobList();
    }

    if (options.isCount) {
      var isSuccess = ((count >= options.min) && ((options.max < 0) || (count <= options.max)));

      var isMin = (options.max < 0);
      var isEqu = (options.max == options.min);

      var details = (isMin ? '$count (actual) >= ${options.min} (min)' :
                     isEqu ? '$count (actual) == ${options.min} (expected)' :
                             '${options.min} (min) <= $count (actual) <= ${options.max} (max)');

      logger.out('${Options.appName}: ${isSuccess ? 'succeeded' : 'failed'}: $details');
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  void execContentFromStdin() {
    if (options.isPathsOnly) {
      logger.debug('Invalid request: ');
    }

    if (logger.isDebug) {
      logger.debug('Scanning the content of ${StringExt.stdinDisplay}');
    }

    for (; ;) {
      var line = stdin.readLineSync(retainNewlines: false)?.trim();

      if (line == null) {
        break;
      }

      execLine(line);
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  Future execEachFileFromGlobList() async {
    var dirNameMap = <String, bool>{};

    if (logger.isDebug) {
      logger.debug('Scanning the content of files from the take-glob list');
    }

    // Collect all distinct lowest level top directory names for the further
    // pick up of all files in those directories and optionally, below

    for (var takeFileGlob in options.takeFileGlobList) {
      var dirName = GlobExt.splitPattern(takeFileGlob.pattern)[0];

      if (logger.isDebug) {
        logger.debug('Getting top directory of the take-glob "$takeFileGlob"');
      }

      if (dirName == '.') {
        dirName = '';
      }

      if (logger.isDebug) {
        logger.debug('...dir: "$dirName"');
      }

      var wasRecursive = dirNameMap[dirName];
      var isRecursive = takeFileGlob.recursive;

      if ((wasRecursive == null) || (!wasRecursive && isRecursive)) {
        if (logger.isDebug) {
          logger.debug('...adding the dir with${isRecursive ? '' : 'out'} recursive scan');
        }
        dirNameMap[dirName] = isRecursive;
      }
    }

    // Loop through every lowest level top directory name

    for (var key in dirNameMap.keys) {
      var topDirName = (key.isEmpty ?
        Path.fileSystem.currentDirectory.path :
        Path.getFullPath(key)
      );

      // Loop through all files in the current directory (and optionally, below)

      var isRecursive = dirNameMap[key] ?? false;
      var entities = Path.fileSystem.directory(topDirName).list(recursive: isRecursive);
      
      await for (var entity in entities) {
        var filePath = entity.path;
        var fileName = Path.basename(filePath);

        var relPath = Path.toPosix(Path.relative(filePath, from: topDirName));

        if (logger.isDebug) {
          logger.debug('Validating the path "$filePath"');
        }

        // If not a file, get the next one

        var stat = await entity.stat();

        if (stat.type != FileSystemEntityType.file) {
          if (logger.isDebug) {
            logger.debug('...not a file - skipping');
          }
          continue;
        }

        // Match the current path against take- and skip-patterns and process the file in case of success

        var isValid = isFilePathMatchedByGlobList(filePath, relPath, fileName, options.takeFileGlobList) &&
                      isFilePathMatchedByRegexList(filePath, relPath, fileName, options.takeFileRegexList) &&
                      !isFilePathMatchedByGlobList(filePath, relPath, fileName, options.skipFileGlobList) &&
                      !isFilePathMatchedByRegexList(filePath, relPath, fileName, options.skipFileRegexList);

        if (isValid) {
          await execFile(filePath, isCheckRequired: false);
        }
      }
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  Future execEachFileFromStdin() async {
    if (logger.isDebug) {
      logger.debug('Scanning the content of files with the paths obtained from ${StringExt.stdinDisplay}');
    }

    // Loop through all file paths in stdin

    for (; ;) {
      var filePath = stdin.readLineSync(retainNewlines: false)?.trim();

      if (filePath == null) {
        break;
      }
      if (filePath.isEmpty) {
        continue;
      }

      var fileName = Path.basename(filePath);

      if (logger.isDebug) {
        logger.debug('Validating the path "$filePath"');
      }

      // Match the current path against skip patterns and process the file in case of success

      var isValid = !isFilePathMatchedByGlobList(filePath, filePath, fileName, options.skipFileGlobList) &&
                    !isFilePathMatchedByRegexList(filePath, filePath, fileName, options.skipFileRegexList);

      if (isValid) {
        await execFile(filePath, isCheckRequired: true);
      }
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  Future execFile(String filePath, {bool isCheckRequired = false}) async {
    if (options.isPathsOnly) {
      logger.out(filePath);
      return;
    }

    if (logger.isDebug) {
      logger.debug('Scanning the file "$filePath"');
    }

    var file = Path.fileSystem.file(filePath);

    if (!isCheckRequired || await file.exists()) {
      var lines = file.openRead().transform(utf8.decoder).transform(_lineSplitter);

      await for (var line in lines) {
        execLine(line);
      }
    }
    else {
      throw Exception('File not found: "${file.path}"');
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  bool execLine(String line) {
    if (logger.isDebug) {
      logger.debug('Validating the line: $line');
    }

    var lineLC = line.toLowerCase();
    var isValid = true;

    // Matching against every plain take-text

    for (var plain in options.takeTextPlainList) {
      if (logger.isDebug) {
        logger.debug('...matching against plain take-text: $plain');
      }

      var isCaseSensitive = (plain[0] == Options.charSensitive);
      isValid = (isCaseSensitive ? line : lineLC).contains(plain.substring(1));

      if (!isValid) {
        break;
      }
    }

    if (!isValid) {
      if (logger.isDebug) {
        logger.debug('...not matched - skipping');
      }
      return false;
    }

    // Matching against every plain skip-text

    for (var plain in options.skipTextPlainList) {
      if (logger.isDebug) {
        logger.debug('...matching against plain skip-text: $plain');
      }

      var isCaseSensitive = (plain[0] == Options.charSensitive);
      isValid = !(isCaseSensitive ? line : lineLC).contains(plain.substring(1));

      if (!isValid) {
        break;
      }
    }

    if (!isValid) {
      if (logger.isDebug) {
        logger.debug('...matched - skipping');
      }
      return false;
    }

    // Matching against every take-regex

    for (var regex in options.takeTextRegexList) {
      if (logger.isDebug) {
        logger.debug('...matching against take-regex: ${regex.pattern}');
      }

      isValid = regex.hasMatch(line);

      if (!isValid) {
        break;
      }
    }

    if (!isValid) {
      if (logger.isDebug) {
        logger.debug('...not matched - skipping');
      }
      return false;
    }

    // Matching against every skip-regex

    for (var regex in options.skipTextRegexList) {
      if (logger.isDebug) {
        logger.debug('...matching against skip-regex: $regex');
      }

      isValid = !regex.hasMatch(line);

      if (!isValid) {
        break;
      }
    }

    if (!isValid) {
      if (logger.isDebug) {
        logger.debug('...matched - skipping');
      }
      return false;
    }

    if (logger.isDebug) {
      logger.debug('...matched');
    }

    if (options.isCount) {
      ++count;
    }
    else {
      logger.out(line);
    }

    return true;
  }

  //////////////////////////////////////////////////////////////////////////////

  bool isFilePathMatchedByGlobList(String filePath, String relPath, String fileName, List<Glob> globList) {
    var isTake = (globList == options.takeFileGlobList);

    for (var glob in globList) {
      if (logger.isDebug) {
        logger.debug('...matching against ${isTake ? 'take' : 'skip'}-glob: ${glob.pattern}');
      }

      var hasDir = glob.pattern.contains(Path.separatorPosix);

      var isMatch = (hasDir ? glob.matches(relPath) : glob.matches(fileName));
      var isValid = (isTake == isMatch);

      if (!isValid) {
        if (logger.isDebug) {
          logger.debug('...${isTake ? 'not ' : ''}matched - skipping');
        }
        return isMatch;
      }
    }

    return isTake;
  }

  //////////////////////////////////////////////////////////////////////////////

  bool isFilePathMatchedByRegexList(String filePath, String relPath, String fileName, List<RegExp> regexList) {
    var isTake = (regexList == options.takeFileRegexList);

    for (var regex in regexList) {
      if (logger.isDebug) {
        logger.debug('...matching against ${isTake ? 'take' : 'skip'}-regex: ${regex.pattern}');
      }

      var hasDir = regex.pattern.contains(Path.separatorPosixEscaped);

      var isMatch = (hasDir ? regex.hasMatch(filePath) : regex.hasMatch(fileName));
      var isValid = (isTake == isMatch);

      if (!isValid) {
        if (logger.isDebug) {
          logger.debug('...${isTake ? 'not ' : ''}matched - skipping');
        }
        return isMatch;
      }
    }

    return isTake;
  }

  //////////////////////////////////////////////////////////////////////////////

}
