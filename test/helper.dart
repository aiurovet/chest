import 'package:file/file.dart';
import 'package:file/memory.dart';

/// A helper class to run tests for every memory-based file system
///
class Helper {
  static const defaultDelay = 10; // milliseconds

  static final memoryFileSystems = [
    MemoryFileSystem(style: FileSystemStyle.posix),
    MemoryFileSystem(style: FileSystemStyle.windows)
  ];

  static void forEachMemoryFileSystem(
      void Function(MemoryFileSystem fs) handler) {
    for (var fs in memoryFileSystems) {
      handler(fs);
    }
  }

  static String getFileSystemStyleName(FileSystem fs) =>
      (fs as StyleableFileSystem).style.toString();
}
