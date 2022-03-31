import 'dart:convert';

import 'package:chest/options.dart';
import 'package:chest/scanner.dart';
import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:get_it/get_it.dart';
import 'package:thin_logger/thin_logger.dart';

/// The global service locator
///
final services = GetIt.instance;

/// Resolving dependencies
///
void registerServices({FileSystem? fs, int logLevel = Logger.levelDefault}) {
  services
    ..allowReassignment = (fs != null)
    ..registerSingleton<FileSystem>(fs ?? LocalFileSystem())
    ..registerSingleton<LineSplitter>(LineSplitter())
    ..registerSingleton<Logger>(Logger(logLevel))
    ..registerSingleton<Options>(Options())
    ..registerSingleton<Scanner>(Scanner());
}
