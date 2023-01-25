// Copyright (c) 2022, Alexander Iurovetski
// All rights reserved under MIT license (see LICENSE file)

import 'package:chest/printer.dart';
import 'package:chest/register_services.dart';
import 'package:file_ext/file_ext.dart';
import 'package:test/test.dart';

/// A suite of tests for Logger
///
void main() async {
  registerServices();

  final printer = Printer(null);

  group('Printer -', () {
    test('init - count and path', () {
      printer.setFormat(':c:p');
      expect(printer.formatItems.toStringList(), [',:', 'c,:', 'p,']);
    });
    test('init - path, line no and content', () {
      printer.setFormat('p: l: t');
      expect(printer.formatItems.toStringList(), ['p,: ', 'l,: ', 't,']);
    });
    test('serialize - stdin - count', () {
      printer.setFormat('c:p');
      expect(printer.formatData(path: '-', count: 123), '123');
    });
    test('serialize - file - count', () {
      printer.setFormat('c|p');
      expect(printer.formatData(path: 'a/b', count: 123), '123|a/b');
    });
    test('serialize - stdin - content', () {
      printer.setFormat('p: t');
      expect(printer.formatData(path: StdinExt.name, content: 'some text'), 'some text');
    });
    test('serialize - file - content', () {
      printer.setFormat('p: t');
      expect(printer.formatData(path: 'a/b', content: 'some text'), 'a/b: some text');
    });
  });
}
