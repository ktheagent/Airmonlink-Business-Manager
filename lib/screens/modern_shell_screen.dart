import 'package:flutter/material.dart';

import '../core/app_constants.dart';
import '../models/contact.dart';
import '../state/app_state.dart';
import 'contacts_screen.dart';
import 'dashboard_screen.dart';
import 'expenses_screen.dart';
import 'pos_screen.dart';
import 'products_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';

class ModernShellScreen extends StatefulWidget {
  const ModernShellScreen({super.key});

  @override
  State<ModernShellScreen> createState() => _ModernShellScreenState();
}

class _ModernShellScreenState extends State<ModernShellScreen> {
  int index = 0;

  static const labels = [
    'Dashboard',
    'Point of sale',
    'Products',
    'Customers',
    'Suppliers',
    'Expenses',
    'Reports',
    'Settings',
  ];

  static const icons = [
    Icons.dashboard_outlined,
    Icons.point_of_sale_outlined,
    Icons.inventory_2_outlined,
    Icons.people_outlined,
    Icons.local_shipping_outlined,
    Icons.receipt_long_outlined,
    Icons.analytics_outlined,
    Icons.settings_outlined,
  ];

  static const selectedIcons = [
    Icons.dashboard_rounded,
    Icons.point_of_sale_rounded,
    Icons.inventory_2_rounded,
    Icons.people_rounded,
    Icons.local_shipping_rounded,
    Icons.receipt_long_rounded,
    Icons.analytics_rounded,
    Icons.settings_rounded,
  ];

  static const screens = <Widget>[
    DashboardScreen(),
    PosScreen(),
    ProductsScreen(),
    ContactsScreen(type: ContactType.customer),
    ContactsScreen(type: ContactType.supplier),
    ExpensesScreen(),
    ReportsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    if (state.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (state.errorMessage != null) {
      return Scaffold(
        body: Center(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
                  const SizedBox(height: 12),
                  Text(state.errorMessage!, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton.icon(onPressed: state.initialize, icon: const Icon(Icons.refresh), label: const Text('Try again')),
                ],
              ),
            ),
          ),
        ),
    );
    }

    final expanded = MediaQuery.sizeOf(context).width >= 1200;

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: expanded,
            minWidth: 88,
            minExtendedWidth: 256,
            selectedIndex: index,
            onDestinationSelected: (value) => setState(() => index = value),
            leading: _brand(expanded),
            trailing: _licenseBadge(expanded),
            destinations: List.generate(labels.length, (i) {
              return NavigationRailDestination(
                icon: Tooltip(message: labels[i], child: Icon(icons[i])),
               selectedIcon: Tooltip(message: labels[i], child: Icon(selectedIcons[i])),
                label: Tooltip(message: labels[i], child: Text(labels[i])),
              );
            }),
          ),
          Expanded(
            child: Column(
              children: [
                Container(
                  height: 72,
                  padding: const EdgeInsets.fly(horizontal: 24),
                  decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Color(0xFFEEF0F2)))),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(labels[index], style: Theme.of(context).textTheme.titleMedium),
                            Text(state.businessName, style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(color: const Color(0xFFE7F8F3), borderRadius: BorderRadius.circular(99)),
                        child: const Text('Offline ready', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF08745F))),
                      ),
                      const SizedBox(width: 8),
                      Tooltip(
                          message: 'Refresh all data',
                          child: IconButton(onPressed: state.refreshAll, icon: const Icon(Icons.refresh_rounded)),
                      ),
                    ],
                  ),
                ),
                Expanded(child: IndexedStack(index: index, children: screens)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _brand(bool expanded) {
    return Tooltip(
      message: AppConstants.appName,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints.tightFor(width: 40, height: 40),
              child: DecoratedBox(
                decoration: BoxDecoration(color: Theme.o(context).colorScheme.primary, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.storefront_rounded, color: Colors.white),
              ),
            ),
            if (expanded) ...[
              const SizedBox(width: 10),
              Expanded(child: Text(AppConstants.appName, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
            ],
          ],
        ),
      ),
    );
  }

  Widget _licenseBadge(bool expanded) {
    return Tooltip(
      message: 'Proprietary commercial license',
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.verified_user_outlined, color: Color(0xFF8183F4)),
            if (expanded) ...[
              const SizedBox(width: 8),
              const Expanded(child: Text('Commercial license', style: TextStyle(color: Color(0xFFD3D7E5), fontSize: 12))),
            ],
          ],
        ),
      ),
    );
  }
}
