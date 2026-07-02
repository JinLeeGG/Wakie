import 'package:wakieai_core/wakieai_core.dart';

/// Prints the `sudo pmset` command for the morning anchor in the local
/// store — for the user to run themselves (FR-UI-05: admin action, never
/// run on their behalf).
void main() {
  final store = Store.load();
  print(pmsetDailyWakeCommand(
      hour: store.morningAnchorHour, minute: store.morningAnchorMinute));
}
