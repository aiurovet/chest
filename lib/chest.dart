import 'dart:io';

import 'package:chest/ext/path.dart';
import 'package:chest/ext/string.dart';
import 'package:chest/logger.dart';
import 'package:chest/options.dart';
import 'package:chest/scanner.dart';

class Chest {

  //////////////////////////////////////////////////////////////////////////////

  final Logger logger;
  final Options options;
  final Scanner scanner;

  //////////////////////////////////////////////////////////////////////////////

  Chest(this.scanner, this.options, this.logger);

  //////////////////////////////////////////////////////////////////////////////

  Future exec(List<String> args) async {
    options.parseAppArgs(args);
    await scanner.exec();
  }

  //////////////////////////////////////////////////////////////////////////////

  void finish(bool isOK) {
    exit(isOK ? 0 : 1);
  }

  //////////////////////////////////////////////////////////////////////////////

  static Future main(List<String> args, Scanner scanner, Options options, Logger logger) async {
    var isOK = false;
    var app = Chest(scanner, options, logger);

    try {
      Path.init(Path.localFileSystem);
      await app.exec(args);
      isOK = true;
    }
    on Error catch (e, stackTrace) {
      isOK = app.onError(e.toString(), stackTrace);
    }
    on Exception catch (e, stackTrace) {
      isOK = app.onError(e.toString(), stackTrace);
    }

    app.finish(isOK);
  }

  //////////////////////////////////////////////////////////////////////////////

  bool onError(String errMsg, StackTrace stackTrace) {
    if (errMsg.isBlank()) {
      return false;
    }
    else {
      var errDecorRE = RegExp(r'^(Exception[\:\s]*)+', caseSensitive: false);
      errMsg = errMsg.replaceFirst(errDecorRE, '');

      if (errMsg.isBlank() || logger.isSilent) {
        return false;
      }

      var errDtl = (logger.level >= Logger.levelDebug ? '\n\n' + stackTrace.toString() : '');
      errMsg = '\n*** ERROR: $errMsg$errDtl\n';

      logger.error(errMsg);

      return false;
    }
  }

  //////////////////////////////////////////////////////////////////////////////

}
