// Copyright (c) 2022-2023, Alexander Iurovetski
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

  /// Get start and end of the pattern's first occurrence in the form of
  /// [ChestMatch].\
  /// In case of plain case-insensitive match, the search strting is
  /// expected to be lowercased already.\
  ///\
  /// Known issue: if the search string is huge, its substring is up to doubling the
  /// memory usage (only in case of the regular expresssion pattern)
  ///
  ChestMatch? firstMatch(String input, [int start = 0]) {
    var end = -1;

    if (regex == null) {
      start = input.indexOf(plain, start);
      end = start + plain.length;
    } else {
      var inputEx = (start == 0 ? input : input.substring(start));
      final match = regex!.firstMatch(inputEx);

      if (match == null) {
        start = -1;
      } else {
        end = start + match.end;
        start += match.start;
      }
    }

    if (negative) {
      start = (start >= 0 ? -1 : 0);
    }

    return (start < 0 ? null : ChestMatch(start, end));
  }
}
