import 'dart:io';

import 'package:chest/src/ext/path.dart';
import 'package:chest/src/ext/string.dart';
import 'package:chest/src/logger.dart';
import 'package:chest/src/options.dart';

class Chest {

  //////////////////////////////////////////////////////////////////////////////

  Logger _logger = Logger();
  Options options = Options();

  //////////////////////////////////////////////////////////////////////////////

  Chest({Logger? logger}) {
    if (logger != null) {
      _logger = logger;
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  void exec(List<String> args) {
    options.parseArgs(args);
  }

  //////////////////////////////////////////////////////////////////////////////

  void finish(bool isOK) {
    exit(isOK ? 0 : 1);
  }

  //////////////////////////////////////////////////////////////////////////////

  static void main(List<String> args) {
    var isOK = false;
    var app = Chest();

    try {
      Path.init(Path.localFileSystem);
      app.exec(args);
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

      if (errMsg.isBlank()) {
        return false;
      }
      else if (errMsg == Options.optHelp['name']) {
        return true;
      }
      else if (_logger.isSilent) {
        return false;
      }

      var errDtl = (_logger.level >= Logger.levelDebug ? '\n\n' + stackTrace.toString() : '');
      errMsg = '\n*** ERROR: $errMsg$errDtl\n';

      _logger.error(errMsg);

      return false;
    }
  }

  //////////////////////////////////////////////////////////////////////////////

}
