import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';

class AppShell extends StatelessWidget {
  const AppShell({required this.location, required this.child, super.key});

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final destinations = [
      (
        path: '/pid',
        icon: Icons.image_search_outlined,
        selected: Icons.image_search,
        label: l10n.pid,
      ),
      (
        path: '/ranking',
        icon: Icons.leaderboard_outlined,
        selected: Icons.leaderboard,
        label: l10n.ranking,
      ),
      (
        path: '/bookmarks',
        icon: Icons.bookmarks_outlined,
        selected: Icons.bookmarks,
        label: l10n.bookmarks,
      ),
      (
        path: '/downloads',
        icon: Icons.download_outlined,
        selected: Icons.download,
        label: l10n.downloads,
      ),
      (
        path: '/settings',
        icon: Icons.settings_outlined,
        selected: Icons.settings,
        label: l10n.settings,
      ),
    ];
    final index = destinations
        .indexWhere((item) => location.startsWith(item.path))
        .clamp(0, destinations.length - 1);
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: MediaQuery.sizeOf(context).width >= 1050,
            selectedIndex: index,
            onDestinationSelected: (value) =>
                context.go(destinations[value].path),
            leading: const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: CircleAvatar(child: Icon(Icons.brush)),
            ),
            destinations: [
              for (final item in destinations)
                NavigationRailDestination(
                  icon: Icon(item.icon),
                  selectedIcon: Icon(item.selected),
                  label: Text(item.label),
                ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}
