// Copyright (c) 2022, Alexander Iurovetski
// All rights reserved under MIT license (see LICENSE file)
//

import 'package:file/file.dart';
import 'package:file/memory.dart';

/// A helper class to run tests for every memory-based file system
///
class Helper {
  /// Const: default delay for file operations
  ///
  static const defaultDelay = 10; // milliseconds

  /// Const: list for [forEachMemoryFileSystem]
  ///
  static final memoryFileSystems = [
    MemoryFileSystem(style: FileSystemStyle.posix),
    MemoryFileSystem(style: FileSystemStyle.windows)
  ];

  /// Loop through all memory file systems
  ///
  static void forEachMemoryFileSystem(
      void Function(MemoryFileSystem fs) handler) {
    for (var fs in memoryFileSystems) {
      handler(fs);
    }
  }

  /// Get the name of a file system
  ///
  static String getFileSystemStyleName(FileSystem fs) {
    final name = (fs as StyleableFileSystem).style.toString();
    final start = name.lastIndexOf('_');
    var end = name.length;
    final lastCode = name[end - 1].toLowerCase().codeUnitAt(0);

    if ((lastCode < 0x60 /* 'a' */) || (lastCode > 0x7A /* 'z' */)) {
      --end;
    }

    return name.substring(start + 1, end);
  }
}
