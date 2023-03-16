// Copyright (c) 2022-2023, Alexander Iurovetski
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

// /// A method to test setCurrentDirectory
// ///
// Future testSetCurrentDirectory(
//     String newDirName, FileSystem fs, Options options) async {
//   var oldCurDirName = fs.currentDirectory.path;
//   newDirName =
//       (newDirName.isEmpty ? oldCurDirName : fs.path.canonicalize(newDirName));

//   var newDir = fs.directory(newDirName);
//   var isNew = !await newDir.exists();

//   if (isNew) {
//     await newDir.create(recursive: true);
//   }

//   await options.setCurrentDirectory(newDirName);
//   expect(fs.path.equals(newDirName, fs.currentDirectory.path), true);

//   if (isNew) {
//     await newDir.delete();
//   }
// }

/// A suite of tests for Logger
///
void main() async {
  Helper.forEachMemoryFileSystem((fs) {
    registerServicesForTests(fs);
    // var s = fs.path.separator;

    group('Options - ${Helper.getFileSystemStyleName(fs)} -', () {
      var options = Options();
      test('parse', () async {
        await options.parse(['-e', '1,2']);
        expect(options.min, 1);
        expect(options.max, 2);
      });
      // test('setCurrentDirectory - empty', () async {
      //   await testSetCurrentDirectory('', fs, options);
      // });
      // test('setCurrentDirectory - root', () async {
      //   await testSetCurrentDirectory('/', fs, options);
      // });
      // test('setCurrentDirectory - a${s}bc${s}def', () async {
      //   await testSetCurrentDirectory('a${s}bc${s}def', fs, options);
      // });
    });
  });
}
