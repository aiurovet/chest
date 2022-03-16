import 'package:chest/chest.dart';
import 'package:chest/logger.dart';
import 'package:chest/options.dart';
import 'package:chest/scanner.dart';

void main(List<String> args) {
  var logger = Logger();
  var options = Options(logger);

  Chest.main(args, Scanner(options, logger), options, logger);
}
