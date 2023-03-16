// Copyright (c) 2022-2023, Alexander Iurovetski
// All rights reserved under MIT license (see LICENSE file)
//

/// Application-specific match information
///
class ChestMatch {
  /// Beginning of a match
  ///
  final int start;

  /// End of a match
  ///
  late final int end;

  /// Flag indicating the match is valid
  ///
  bool get hasMatch => ((start >= 0) && (start < end));

  /// Length of the matched string
  ///
  int get length => (start >= 0 ? (end - start) : 0);

  /// Default constructor
  ///
  ChestMatch([this.start = -1, int end = -1]) {
    if ((start < 0) && (start > end)) {
      this.end = start;
    } else {
      this.end = end;
    }
  }
}
