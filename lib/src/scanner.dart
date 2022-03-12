import 'dart:convert';
import 'dart:io';

import 'package:file/file.dart';
import 'package:glob/glob.dart';
import 'package:chest/src/ext/path.dart';
import 'package:chest/src/options.dart';

class Scanner {

  //////////////////////////////////////////////////////////////////////////////

  final Options _options;

  late final String _skipPlain;
  late final RegExp _skipRegex;

  late final String _takePlain;
  late final RegExp _takeRegex;

  late final bool _isSkipPlain;
  late final bool _isSkipPlainCaseSensitive;
  late final bool _isSkipRegex;

  late final bool _isTakePlain;
  late final bool _isTakePlainCaseSensitive;
  late final bool _isTakeRegex;

  //////////////////////////////////////////////////////////////////////////////

  Scanner(this._options) {
    _skipPlain = _options.skipTextPlain.substring(1);
    _skipRegex = _options.skipTextRegex;

    _takePlain = _options.takeTextPlain.substring(1);
    _takeRegex = _options.takeTextRegex;

    _isSkipPlain = _skipPlain.isNotEmpty;
    _isSkipPlainCaseSensitive = (_options.skipTextPlain[0] == Options.charSensitive);
    _isSkipRegex = _skipRegex.pattern.isNotEmpty;

    _isTakePlain = _takePlain.isNotEmpty;
    _isTakePlainCaseSensitive = (_options.takeTextPlain[0] == Options.charSensitive);
    _isTakeRegex = _takeRegex.pattern.isNotEmpty;
  }

  //////////////////////////////////////////////////////////////////////////////

  void exec() {
    var take = _options.take;

    if (_options.isTakeFilesFromStdin) {
      execEachFileFromStdin();
    }
    else if (take == null) {
      execContentFromStdin();
    }
    else {
      execEachFileFromGlob(take);
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  void execContentFromStdin() {
    for (; ;) {
      var line = stdin.readLineSync(retainNewlines: false)?.trim();

      if (line == null) {
        break;
      }

      execLine(line);
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  void execEachFileFromGlob(Glob take) {
    var skip = _options.skip;
    var entities = take.listFileSystemSync(Path.fileSystem);

    for (var entity in entities) {
      var filePath = entity.path;

      if ((skip != null) && skip.matches(filePath)) {
        continue;
      }

      execFile(filePath);
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  void execEachFileFromStdin() {
    var skip = _options.skip;

    for (; ;) {
      var filePath = stdin.readLineSync(retainNewlines: false)?.trim();

      if (filePath == null) {
        break;
      }
      if (filePath.isEmpty || ((skip != null) && skip.matches(filePath))) {
        continue;
      }

      execFile(filePath);
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  void execFiles(List<FileSystemEntity> entities) {
    var skip = _options.skip;

    for (var entity in entities) {
      if ((skip != null) && skip.matches(entity.path)) {
        continue;
      }

      var file = Path.fileSystem.file(entity.path);

      if (!file.existsSync()) {
        throw Exception('File not found: "${file.path}"');
      }

      file.openRead().transform(utf8.decoder).transform(LineSplitter()).forEach(execLine);
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  void execFile(String filePath) {
    var file = Path.fileSystem.file(filePath);

    if (file.existsSync()) {
      file.openRead().transform(utf8.decoder).transform(LineSplitter()).forEach(execLine);
    }
    else {
      throw Exception('File not found: "${file.path}"');
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  bool execLine(String line) {
    var lineLC = (
      ( _isTakePlain && ! _isTakePlainCaseSensitive) || (! _isTakePlain && !_takeRegex.isCaseSensitive) ||
      (_isSkipPlain && !_isSkipPlainCaseSensitive) || (!_isSkipPlain && !_skipRegex.isCaseSensitive) ?
        line.toLowerCase() : ''
    );

    if (_isTakePlain) {
      if (_isTakePlainCaseSensitive && !line.contains(_takePlain)) {
        return false;
      }
      if (!_isTakePlainCaseSensitive && !lineLC.contains(_takePlain)) {
        return false;
      }
    }
    else {
      if (_isTakeRegex && !_takeRegex.hasMatch(_takeRegex.isCaseSensitive ? line : lineLC)) {
        return false;
      }
    }
    if (_isSkipPlain) {
      if (_isSkipPlainCaseSensitive && line.contains(_skipPlain)) {
        return false;
      }
      if (!_isSkipPlainCaseSensitive && lineLC.contains(_skipPlain)) {
        return false;
      }
    }
    else
    {
      if (_isSkipRegex && _skipRegex.hasMatch(_skipRegex.isCaseSensitive ? line : lineLC)) {
        return false;
      }
    }

    return true;
  }

  //////////////////////////////////////////////////////////////////////////////

  void getFileList(String take, String skip) {
  }

  //////////////////////////////////////////////////////////////////////////////

}
