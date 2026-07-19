import 'package:flutter/material.dart';

import '../core/app_constants.dart';
import '../models/contact.dart';
import '../state/app_state.dart';
import 'contacts_screen.dart';
import 'dashboard_screen.dart';
import 'expenses_screen.dart';
import 'license_screen.dart';
import 'pos_screen.dart';
import 'products_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';

class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int index = 0;
  bool expanded = true;

  static const screens = <Widget>[
    DashboardScreen(),
    PosScreen(),
    ProductsScreen(),
    ContactsScreen(type: ContactType.customer),
    ContactsScreen(type: ContactType.supplier),
    ExpensesScreen(),
    ReportsScreen(),
    LicenseScreen(),
    SettingsScreen(),
  ];

  static const destinations = <_NavItem>[
    _NavItem(
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard,
      label: 'Dashboard',
    ),
    _NavItem(
      icon: Icons.point_of_sale_outlined,
      selectedIcon: Icons.point_of_sale,
      label: 'Point of sale',
    ),
    _NavItem(
      icon: Icons.inventory_2_outlined,
      selectedIcon: Icons.inventory_2,
      label: 'Products',
    ),
    _NavItem(
      icon: Icons.people_outline,
      selectedIcon: Icons.people,
      label: 'Customers',
    ),
    _NavItem(
      icon: Icons.local_shipping_outlined,
      selectedIcon: Icons.local_shipping,
      label: 'Suppliers',
    ),
    _NavItem(
      icon: Icons.receipt_long_outlined,
      selectedIcon: Icons.receipt_long,
      label: 'Expenses',
    ),
    _NavItem(
      icon: Icons.analytics_outlined,
      selectedIcon: Icons.analytics,
      label: 'Reports',
    ),
    _NavItem(
      icon: Icons.workspace_premium_outlined,
      selectedIcon: Icons.workspace_premium,
      label: 'Licence',
    ),
    _NavItem(
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
      label: 'Settings',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final isWide = MediaQuery.sizeOf(context).width >= 1280;
    if (state.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (state.errorMessage != null) {
      return Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 52,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'The application could not start.',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(state.errorMessage!, textAlign: TextAlign.center),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: state.initialize,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF2F5FB),
      body: Row(
        children: [
          Container(
            width: expanded && isWide ? 268 : 92,
            decoration: const BoxDecoration(color: Color(0xFF0F2A5A)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 14),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.asset(
                          'assets/branding/airmonlink_business_manager_logo.png',
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                        ),
                      ),
                      if (expanded && isWide) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppConstants.appName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Commercial desktop edition',
                                style: TextStyle(
                                  color: Color(0xFFBFD6FF),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Divider(color: Color(0xFF183B72), thickness: 1),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 10,
                    ),
                    itemCount: destinations.length,
                    itemBuilder: (context, position) {
                      final item = destinations[position];
                      final selected = index == position;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Tooltip(
                          message: expanded && isWide ? item.label : item.label,
                          child: InkWell(
                            onTap: () => setState(() => index = position),
                            borderRadius: BorderRadius.circular(16),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                color: selected
                                    ? const Color(0xFF2F6DEB)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    selected ? item.selectedIcon : item.icon,
                                    color: selected
                                        ? Colors.white
                                        : const Color(0xFFBFD6FF),
                                    size: 22,
                                  ),
                                  if (expanded && isWide) ...[
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        item.label,
                                        style: TextStyle(
                                          color: selected
                                              ? Colors.white
                                              : const Color(0xFFBFD6FF),
                                          fontWeight: selected
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                  child: Tooltip(
                    message: expanded && isWide
                        ? 'Collapse navigation'
                        : 'Expand navigation',
                    child: InkWell(
                      onTap: () => setState(() => expanded = !expanded),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF183B72),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          expanded ? Icons.chevron_left : Icons.chevron_right,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  color: const Color(0xFFFFFFFF),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              state.businessName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F2A5A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Premium business operations • ${DateTime.now().toLocal().toString().split('.').first}',
                              style: const TextStyle(
                                color: Color(0xFF5C6B7A),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F6FD),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.verified_outlined,
                              color: Color(0xFF2F6DEB),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              state.settings['business_name'] != null
                                  ? 'Licensed'
                                  : 'Setup required',
                              style: const TextStyle(
                                color: Color(0xFF0F2A5A),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: IndexedStack(index: index, children: screens),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}
