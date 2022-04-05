import 'package:chest/register_services.dart';
import 'package:chest/ext/path_ext.dart';
import 'package:file/file.dart';
import 'package:test/test.dart';
import 'package:chest/ext/glob_ext.dart';
import 'package:thin_logger/thin_logger.dart';
import '../helper.dart';

/// Test services registration
///
registerServicesForTests(FileSystem fs) =>
    registerServices(fs: fs, logLevel: Logger.levelQuiet);

/// A suite of tests for Glob
///
void main() {
  Helper.forEachMemoryFileSystem((fs) {
    registerServicesForTests(fs);
    var fsp = fs.path;
    var sep = fsp.separator;
    var isPosixFS = fsp.isPosix;
    var nonPosixSuffix = isPosixFS ? ' - N/A' : '';

    group('Glob - ${Helper.getFileSystemStyleName(fs)} -', () {
      test('fromFileSystemPattern - null', () {
        var g = GlobExt.fromFileSystemPattern(fs, null);
        expect(g.pattern, '*');
        expect(g.recursive, false);
        expect(g.caseSensitive, fsp.isCaseSensitive);
      });
      test('fromFileSystemPattern - empty', () {
        var g = GlobExt.fromFileSystemPattern(fs, '');
        expect(g.pattern, '*');
        expect(g.recursive, false);
        expect(g.caseSensitive, fsp.isCaseSensitive);
      });
      test('fromFileSystemPattern - actual path with recursiveness', () {
        var g = GlobExt.fromFileSystemPattern(fs, 'Abc${sep}De$sep**.txt');
        expect(g.pattern, 'Abc${sep}De$sep**.txt{,/**}');
        expect(g.recursive, true);
        expect(g.caseSensitive, fsp.isCaseSensitive);
      });
      test('isGlobPattern - null', () {
        expect(GlobExt.isGlobPattern(null), false);
      });
      test('isGlobPattern - empty', () {
        expect(GlobExt.isGlobPattern(''), false);
      });
      test('isGlobPattern - #1', () {
        expect(GlobExt.isGlobPattern('abc.def'), false);
      });
      test('isGlobPattern - #2', () {
        expect(GlobExt.isGlobPattern('abc?.def'), true);
      });
      test('isGlobPattern - #3', () {
        expect(GlobExt.isGlobPattern('abc*.def'), true);
      });
      test('isGlobPattern - #4', () {
        expect(GlobExt.isGlobPattern('dir${sep}abc.{def,gh}'), true);
      });
      test('isRecursive - empty', () {
        expect(GlobExt.isRecursiveGlobPattern(''), false);
      });
      test('isRecursive - #1', () {
        expect(GlobExt.isRecursiveGlobPattern('abc*.def'), false);
      });
      test('isRecursive - #2', () {
        expect(GlobExt.isRecursiveGlobPattern('abc**x.def'), true);
      });
      test('isRecursive - #3', () {
        expect(GlobExt.isRecursiveGlobPattern('**${sep}abc*.def'), true);
      });
      test('isRecursive - #4', () {
        expect(GlobExt.isRecursiveGlobPattern('xy**${sep}abc*.def'), true);
      });
      test('toRootAndPattern - #1', () {
        var parts = GlobExt.toRootAndPattern(fs, 'x');
        expect(parts[0], '');
        expect(parts[1], 'x');
      });
      test('toRootAndPattern - #2', () {
        var parts = GlobExt.toRootAndPattern(fs, '*abc*.def');
        expect(parts[0], '');
        expect(parts[1], '*abc*.def');
      });
      test('toRootAndPattern - #3', () {
        var parts = GlobExt.toRootAndPattern(fs, 'sub-dir$sep*abc*.def');
        expect(parts[0], 'sub-dir');
        expect(parts[1], '*abc*.def');
      });
      test('toRootAndPattern - #4', () {
        var parts = GlobExt.toRootAndPattern(fs, '../../sub-dir$sep*abc*.def');
        expect(parts[0], '..$sep..${sep}sub-dir');
        expect(parts[1], '*abc*.def');
      });
      test('toRootAndPattern - #5', () {
        var parts = GlobExt.toRootAndPattern(fs, 'sub-dir**$sep*abc*.def');
        expect(parts[0], '');
        expect(parts[1], 'sub-dir**$sep*abc*.def');
      });
      test('toRootAndPattern - #6', () {
        var parts = GlobExt.toRootAndPattern(fs, 'top-dir${sep}sub-dir**$sep*abc*.def');
        expect(parts[0], 'top-dir');
        expect(parts[1], 'sub-dir**$sep*abc*.def');
      });
      test('toRootAndPattern - #7$nonPosixSuffix', () {
        if (!isPosixFS) {
          var parts = GlobExt.toRootAndPattern(fs, 'c:sub-dir$sep*abc*.def');
          expect(parts[0], 'c:sub-dir');
          expect(parts[1], '*abc*.def');
        }
      });
      test('toRootAndPattern - #8$nonPosixSuffix', () {
        if (!isPosixFS) {
          var parts = GlobExt.toRootAndPattern(fs, r'c:\*.txt');
          expect(parts[0], r'c:\');
          expect(parts[1], '*.txt');
        }
      });
      test('toRootAndPattern - #9', () {
        var parts = GlobExt.toRootAndPattern(fs, '/');
        expect(parts[0], sep);
        expect(parts[1], '*');
      });
      test('toRootAndPattern - #10', () {
        var parts = GlobExt.toRootAndPattern(fs, '/*.txt');
        expect(parts[0], sep);
        expect(parts[1], '*.txt');
      });
      test('toRootAndPattern - #11', () {
        var parts = GlobExt.toRootAndPattern(fs, '/a/*.txt');
        expect(parts[0], '${sep}a');
        expect(parts[1], '*.txt');
      });
    });
  });
}
