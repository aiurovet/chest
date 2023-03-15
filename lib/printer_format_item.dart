// Copyright (c) 2022-23, Alexander Iurovetski
// All rights reserved under MIT license (see LICENSE file)
//

/// Supplementary class for the format elements
///
class PrinterFormatItem {
  /// What to print before the field
  ///
  String prefix;

  /// Which field to print
  ///
  String fstr;

  /// What to print after the field
  ///
  String suffix;

  /// Default constructor
  ///
  PrinterFormatItem([this.prefix = '', this.fstr = '', this.suffix = '']);
}
