import 'package:flutter/widgets.dart';

/// Global navigator key used by:
///   - go_router (as navigatorKey so we can navigate from outside widget tree)
///   - FcmService (to route on push tap)
///   - flutter_local_notifications (to route on local notif tap)
final GlobalKey<NavigatorState> rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');
