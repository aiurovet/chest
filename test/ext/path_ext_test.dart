import 'package:chest/register_services.dart';
import 'package:chest/ext/path_ext.dart';
import 'package:file/file.dart';
import 'package:test/test.dart';
import 'package:thin_logger/thin_logger.dart';
import '../helper.dart';

/// Test services registration
///
registerServicesForTests(FileSystem fs) =>
    registerServices(fs: fs, logLevel: Logger.levelQuiet);

/// A suite of tests for Path
///
void main() {
  Helper.forEachMemoryFileSystem((fs) {
    registerServicesForTests(fs);
    var sep = fs.path.separator;

    group('PathExt - ${Helper.getFileSystemStyleName(fs)} -', () {
      test('adjust', () {
        expect(fs.path.adjust(null), '');
        expect(fs.path.adjust(''), '');
        expect(fs.path.adjust(r'\a\bc/def'), '${sep}a${sep}bc${sep}def');
      });
      test('getFullPath', () {
        var curDir = fs.currentDirectory.path;

        expect(fs.path.equals(fs.path.getFullPath(''), curDir), true);
        expect(fs.path.equals(fs.path.getFullPath('.'), curDir), true);
        expect(
            fs.path.equals(fs.path.getFullPath('..'), fs.path.dirname(curDir)),
            true);
        expect(
            fs.path.equals(fs.path.getFullPath('..${sep}a${sep}bc'),
                '${fs.path.dirname(curDir)}${sep}a${sep}bc'),
            true);
        expect(
            fs.path.equals(
                fs.path.getFullPath('${sep}a${sep}bc'), '${sep}a${sep}bc'),
            true);
        expect(fs.path.equals(fs.path.getFullPath('${sep}Abc.txt'), r'Abc.txt'),
            true);
        expect(
            fs.path.equals(
                fs.path.getFullPath('$sepСаша.Текст'), '$sepСаша.Текст'),
            true);
      });
    });
  });
}
