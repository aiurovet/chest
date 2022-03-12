import 'dart:convert';
import 'dart:io';

import 'package:file/file.dart';
import 'package:glob/glob.dart';
import 'package:chest/src/ext/path.dart';
import 'package:chest/src/options.dart';

class Scanner {

  final Options _options;

  //////////////////////////////////////////////////////////////////////////////

  Scanner(this._options);

  //////////////////////////////////////////////////////////////////////////////

  List<String> exec() {
    var take = _options.take;

    if (_options.isTakeStdin) {
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
    var plain = _options.plain;
    var regex = _options.regex;

    var isPlain = plain.isEmpty;

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

  void execLine(String line, String plain, RegExp? regex, bool isCaseSensitve) {
    if (plain.isNotEmpty) {
      if (isCaseSensitve) {
        if (!line.contains(plain)) {
          return;
        }
      }
      else {
        if (!line.toLowerCase().contains(plain)) {
          return;
        }
      }
    }
    else if (regex != null) {
      if (!regex.hasMatch(line)) {
        return;
      }
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  void getFileList(String take, String skip) {
  }

  //////////////////////////////////////////////////////////////////////////////

}
