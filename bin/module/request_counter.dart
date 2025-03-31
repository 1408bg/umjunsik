import 'dart:math';

import 'package:nyxx/nyxx.dart';

class RequestCounter {
  final bool allowMinus;
  final Map<Snowflake, int> counter;

  RequestCounter({this.allowMinus = false}) : counter = {};

  void add(Snowflake key, int value, {Duration? duration}) {
    if (duration != null) {
      Future.delayed(duration, () => add(key, -value));
    }
    final current = counter[key] ?? 0;
    final newValue = current + value;
    counter[key] = allowMinus ? newValue : max(0, newValue);
  }

  int get(Snowflake key) {
    return counter[key] ?? 0;
  }
}
