// Copyright (c) 2022, Alexander Iurovetski
// All rights reserved under MIT license (see LICENSE file)
//

import 'package:chest/chest_match.dart';

/// Application-specific pattern information
///
class ChestPattern {
  /// Is true if the opposite match expected
  ///
  final bool negative;

  /// Is true if case-sensitive match expected
  ///
  final bool caseSensitive;

  /// Is true multi-line match expected
  ///
  final bool multiLine;

  /// Plain text pattern
  ///
  late final String plain;

  /// Regular expression pattern
  ///
  late final RegExp? regex;

  /// Default constructor
  ///
  ChestPattern(String? pattern,
      {this.caseSensitive = true,
      this.multiLine = false,
      this.negative = false,
      bool regular = false}) {
    if ((pattern == null) || pattern.isEmpty) {
      plain = '';
      regex = null;
      return;
    }

    if (regular) {
      plain = '';
      regex = RegExp(pattern,
          caseSensitive: caseSensitive,
          dotAll: multiLine,
          multiLine: multiLine,
          unicode: pattern.codeUnits.any((x) => (x >= 0x80)));
      return;
    }

    plain = (caseSensitive ? pattern : pattern.toLowerCase());
    regex = null;
  }

  /// Get start and end of the pattern first occurrence
  /// In case of plain case-insensitive match, [input]
  /// is expected to be lowercased already
  ///
  ChestMatch? firstMatch(String input, {bool canLower = false, int start = 0}) {
    var end = -1;

    if (regex != null) {
      final match = regex!.firstMatch(input);
      start = match?.start ?? -1;
      end = match?.end ?? -1;
    } else {
      if (caseSensitive || !canLower) {
        start = input.indexOf(plain, start);
      } else {
        start = input.toLowerCase().indexOf(plain, start);
      }
      end = input.length;
    }

    if (negative) {
      start = (start >= 0 ? -1 : 0);
    }

    return (start < 0 ? null : ChestMatch(start, end));
  }
}
