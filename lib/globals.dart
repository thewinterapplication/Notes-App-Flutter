import 'package:flutter/material.dart';

/// Global navigator key so non-widget code (e.g. ApiService) can navigate,
/// such as forcing the user back to login when their session is revoked.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
