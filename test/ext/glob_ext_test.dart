import 'package:chest/register_services.dart';
import 'package:chest/ext/path_ext.dart';
import 'package:file/file.dart';
import 'package:glob/glob.dart';
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
    var sep = fs.path.separator;

    group('Glob - ${Helper.getFileSystemStyleName(fs)} -', () {
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
        expect(GlobExt.isRecursive(''), false);
      });
      test('isRecursive - #1', () {
        expect(GlobExt.isRecursive('abc*.def'), false);
      });
      test('isRecursive - #2', () {
        expect(GlobExt.isRecursive('abc**x.def'), true);
      });
      test('isRecursive - #3', () {
        expect(GlobExt.isRecursive('**${sep}abc*.def'), true);
      });
      test('isRecursive - #4', () {
        expect(GlobExt.isRecursive('xy**${sep}abc*.def'), true);
      });
      test('split - #1', () {
        var parts = Glob('x').split(fs);
        expect(parts[0], '');
        expect(parts[1], 'x');
      });
      test('split - #2', () {
        var parts = Glob('*abc*.def').split(fs);
        expect(parts[0], '');
        expect(parts[1], '*abc*.def');
      });
      test('split - #3', () {
        var parts = Glob('sub-dir$sep*abc*.def').split(fs);
        expect(parts[0], 'sub-dir');
        expect(parts[1], '*abc*.def');
      });
      test('split - #4', () {
        var parts = Glob('../../sub-dir$sep*abc*.def').split(fs);
        expect(parts[0], '../../sub-dir');
        expect(parts[1], '*abc*.def');
      });
      test('split - #5', () {
        var parts = Glob('sub-dir**$sep*abc*.def').split(fs);
        expect(parts[0], '');
        expect(parts[1], 'sub-dir**$sep*abc*.def');
      });
      test('split - #6', () {
        var parts = Glob('top-dir${sep}sub-dir**$sep*abc*.def').split(fs);
        expect(parts[0], 'top-dir');
        expect(parts[1], 'sub-dir**$sep*abc*.def');
      });
      test('split - #7', () {
        if (!fs.path.isPosix) {
          var parts = Glob('c:sub-dir$sep*abc*.def').split(fs);
          expect(parts[0], 'c:sub-dir');
          expect(parts[1], '*abc*.def');
        }
      });
      test('toGlob - null', () {
        var g = GlobExt.toGlob(null, fs);
        expect(g.pattern, '*');
        expect(g.recursive, false);
        expect(g.caseSensitive, fs.path.isCaseSensitive);
      });
      test('toGlob - empty', () {
        var g = GlobExt.toGlob('', fs);
        expect(g.pattern, '*');
        expect(g.recursive, false);
        expect(g.caseSensitive, fs.path.isCaseSensitive);
      });
      test('toGlob - actual path with recursiveness', () {
        var g = GlobExt.toGlob('Abc${sep}De$sep**.txt', fs);
        expect(g.pattern, 'Abc/De/**.txt{,/**}');
        expect(g.recursive, true);
        expect(g.caseSensitive, fs.path.isCaseSensitive);
      });
    });
  });
}
