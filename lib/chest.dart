// Copyright (c) 2022, Alexander Iurovetski
// All rights reserved under MIT license (see LICENSE file)

import 'dart:io';
import 'package:chest/register_services.dart';
import 'package:thin_logger/thin_logger.dart';

import 'package:chest/options.dart';
import 'package:chest/scanner.dart';

/// The main application class
///
class Chest {
  // Dependency injection
  //
  final _logger = services.get<Logger>();
  final _options = services.get<Options>();
  final _scanner = services.get<Scanner>();

  /// The constructor
  ///
  Chest();

  /// The processor
  ///
  Future exec(List<String> args) async {
    await _options.parse(args);
    await _scanner.exec();
  }

  /// The application entry point
  ///
  static Future main(List<String> args) async {
    var isOK = false;

    registerServices();

    var app = Chest();

    try {
      await app.exec(args);
      isOK = true;
    } on Error catch (e, stackTrace) {
      isOK = app.onError(e.toString(), stackTrace);
    } on Exception catch (e, stackTrace) {
      isOK = app.onError(e.toString(), stackTrace);
    }

    exit(isOK ? 0 : 1);
  }

  /// The error handler
  ///
  bool onError(String errMsg, StackTrace stackTrace) {
    if (errMsg.isEmpty) {
      return false;
    } else {
      var errDecorRE = RegExp(r'^(Exception[\:\s]*)+', caseSensitive: false);
      errMsg = errMsg.replaceFirst(errDecorRE, '');

      if (errMsg.isEmpty || _logger.isQuiet) {
        return false;
      }

      var errDtl = (_logger.level >= Logger.levelVerbose
          ? '\n\n' + stackTrace.toString()
          : '');
      errMsg = '\n*** ERROR: $errMsg$errDtl\n';

      _logger.error(errMsg);

      return false;
    }
  }
}
