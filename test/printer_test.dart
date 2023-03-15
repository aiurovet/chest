// Copyright (c) 2022-23, Alexander Iurovetski
// All rights reserved under MIT license (see LICENSE file)

import 'package:chest/printer.dart';
import 'package:chest/register_services.dart';
import 'package:test/test.dart';
import 'package:utf_ext/utf_ext.dart';

/// A suite of tests for Logger
///
void main() async {
  registerServices();

  final printer = Printer(null);

  group('Printer -', () {
    test('init - count and path', () {
      printer.setFormat(':%c:%p');
      final pf = printer.formatItems;
      final s1 = '${pf[0].prefix} ${pf[0].fstr} ${pf[0].suffix}';
      final s2 = '${pf[1].prefix} ${pf[1].fstr} ${pf[1].suffix}';
      expect('$s1|$s2', ': %c :| %p ');
    });
    test('init - path, line no and content', () {
      printer.setFormat('%p%t%l: %s%n');
      final pf = printer.formatItems;
      final s1 = '${pf[0].prefix} ${pf[0].fstr} ${pf[0].suffix}';
      final s2 = '${pf[1].prefix} ${pf[1].fstr} ${pf[1].suffix}';
      final s3 = '${pf[2].prefix} ${pf[2].fstr} ${pf[2].suffix}';
      expect('$s1|$s2|$s3', ' %p \t| %l : | %s \n');
    });
    test('formatData - stdin - count', () {
      printer.setFormat('%c:%p');
      expect(printer.formatData(path: '-', count: 123), '123:-');
    });
    test('formatData - file - count', () {
      printer.setFormat('%c|%p');
      expect(printer.formatData(path: 'a/b', count: 123), '123|a/b');
    });
    test('formatData - stdin - content', () {
      printer.setFormat('%p: %s');
      expect(printer.formatData(path: UtfStdin.name, content: 'some text'),
          '${UtfStdin.name}: some text');
    });
    test('formatData - file - content', () {
      printer.setFormat('%p: %s');
      expect(
          printer.formatData(
              path: 'a/b', content: 'line 1\nl 2\nlong line 3\n'),
          'a/b: line 1\na/b: l 2\na/b: long line 3\na/b: ');
    });
    test('formatData - no first field', () {
      printer.setFormat('%p: %s');
      expect(printer.formatData(content: 'content'), 'content');
    });
    test('formatData - no last field', () {
      printer.setFormat('%p: %s');
      expect(printer.formatData(path: 'abc.txt'), 'abc.txt');
    });
    test('formatData - no middle field', () {
      printer.setFormat('%p: %l%t%s');
      final result = printer.formatData(path: 'abc.txt', content: 'content');
      expect(result, 'abc.txt: content');
    });
    test('formatData - ends with separator', () {
      printer.setFormat('%s %n %t %n');
      expect(printer.formatData(content: 'content'), 'content \n \t \n');
    });
  });
}
