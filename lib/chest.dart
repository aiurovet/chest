// Copyright (c) 2022-23, Alexander Iurovetski
// All rights reserved under MIT license (see LICENSE file)
//
import 'dart:io';
import 'package:chest/options.dart';
import 'package:chest/scanner.dart';
import 'package:chest/register_services.dart';
import 'package:thin_logger/thin_logger.dart';

/// The main application class
///
class Chest {
  /// Dependency injection
  ///
  final _logger = services.get<Logger>();
  final _options = services.get<Options>();
  final _scanner = services.get<Scanner>();

  /// The constructor
  ///
  Chest();

  /// The processor
  ///
  Future<bool> exec(List<String> args) async {
    await _options.parse(args);
    return await _scanner.exec();
  }

  /// The application entry point
  ///
  static Future main(List<String> args) async {
    late final Chest app;

    var isOK = false;

    try {
      registerServices();
      app = Chest();
      isOK = await app.exec(args);
    } on Error catch (e, stackTrace) {
      app.onError(e.toString(), stackTrace);
    } on Exception catch (e, stackTrace) {
      app.onError(e.toString(), stackTrace);
    }

    exit(isOK ? 0 : 1);
  }

  /// The error handler
  ///
  void onError(String errMsg, StackTrace stackTrace) {
    if (errMsg.isEmpty) {
      return;
    }

    var errDecorRE = RegExp(r'^(Exception[\:\s]*)+', caseSensitive: false);
    errMsg = errMsg.replaceFirst(errDecorRE, '');

    if (errMsg.isEmpty || _logger.isQuiet) {
      return;
    }

    var errDtl =
        (_logger.level >= Logger.levelVerbose ? '\n\n$stackTrace' : '');
    errMsg = '\n*** ERROR: $errMsg$errDtl\n';

    _logger.error(errMsg);
  }
}
