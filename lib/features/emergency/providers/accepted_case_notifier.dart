import 'package:flutter/foundation.dart';

/// Singleton notifier so the Emergency Detail screen can hand off the
/// accepted emergency id to the Map screen without depending on navigation
/// query params (which don't round-trip through StatefulShellRoute reliably).
class AcceptedCaseNotifier extends ValueNotifier<String?> {
  AcceptedCaseNotifier._() : super(null);
  static final AcceptedCaseNotifier instance = AcceptedCaseNotifier._();

  void set(String id) => value = id;
  void clear() => value = null;
}
