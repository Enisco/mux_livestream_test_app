import 'package:go_router/go_router.dart';

import 'package:test_app/core/router.dart';
import 'package:test_app/core/transitions.dart';
import 'package:test_app/features/landing/views/main_shell.dart';

final List<RouteBase> shellRoutes = [
  GoRoute(
    path: AppRouter.home,
    pageBuilder: (context, state) => fadeTransition(state, const MainShell()),
  ),
];
