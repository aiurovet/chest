// Copyright (c) 2022, Alexander Iurovetski
// All rights reserved under MIT license (see LICENSE file)
import 'package:chest/register_services.dart';
import 'package:file/file.dart';
import 'package:test/test.dart';
import 'package:chest/options.dart';
import 'package:thin_logger/thin_logger.dart';
import 'helper.dart';

/// Test services registration
///
registerServicesForTests(FileSystem fs) =>
    registerServices(fs: fs, logLevel: Logger.levelQuiet);

/// A suite of tests for Logger
///
void main() async {
  Helper.forEachMemoryFileSystem((fs) {
    registerServicesForTests(fs);

    group('Scanner - ${Helper.getFileSystemStyleName(fs)} -', () {
      var options = services.get<Options>();
      test('parse', () async {
        await options.parse(['-e', '1..2']);
        expect(options.min, 1);
        expect(options.max, 2);
      });
    });
  });
}
