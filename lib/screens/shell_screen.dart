import 'package:flutter/material.dart';

import '../commercial/models/commercial_models.dart';
import '../commercial/screens/commercial_suite_screen.dart';
import '../commercial/screens/staff_access_screen.dart';
import '../core/app_constants.dart';
import '../licensing/license_controller.dart';
import '../models/contact.dart';
import '../state/app_state.dart';
import '../widgets/feedback.dart';
import '../widgets/license_status_badge.dart';
import 'contacts_screen.dart';
import 'dashboard_screen.dart';
import 'expenses_screen.dart';
import 'license_screen.dart';
import 'pos_screen.dart';
import 'products_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';

class ShellScreen extends StatefulWidget {
  const ShellScreen({required this.licenseController, super.key});

  final LicenseController licenseController;

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int index = 0;
  bool expanded = true;

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    if (state.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (state.errorMessage != null) return _startupError(context, state);
    if (state.currentUser == null) {
      return const StaffAccessScreen();
    }

    final destinations = _destinations(state);
    if (index >= destinations.length) index = 0;
    final isWide = MediaQuery.sizeOf(context).width >= 1280;
    final user = state.currentUser!;
    final branch = state.branches
        .where((item) => item.id == user.branchId)
        .firstOrNull;

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
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppConstants.appName,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Premium commercial edition',
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
                          message: item.label,
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
                    vertical: 13,
                  ),
                  color: Colors.white,
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
                              '${branch?.name ?? 'Main Branch'} • ${user.name} • ${user.role.label}',
                              style: const TextStyle(
                                color: Color(0xFF5C6B7A),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if ((user.role == StaffRole.owner ||
                              user.role == StaffRole.manager) &&
                          state.branches.length > 1)
                        Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: SizedBox(
                            width: 190,
                            child: DropdownButtonFormField<int>(
                              initialValue: user.branchId,
                              decoration: const InputDecoration(
                                labelText: 'Working branch',
                                isDense: true,
                                prefixIcon: Icon(Icons.store_mall_directory_outlined),
                              ),
                              items: state.branches
                                  .where((item) => item.isActive)
                                  .map(
                                    (item) => DropdownMenuItem<int>(
                                      value: item.id,
                                      child: Text(
                                        item.name,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(growable: false),
                              onChanged: (branchId) async {
                                if (branchId == null || branchId == user.branchId) {
                                  return;
                                }
                                try {
                                  await state.switchBranch(branchId);
                                  if (!mounted) return;
                                  setState(() => index = 0);
                                  showSuccess(context, 'Working branch changed.');
                                } catch (error) {
                                  if (mounted) showFailure(context, error);
                                }
                              },
                            ),
                          ),
                        ),
                      if (state.currentCashSession != null)
                        const Padding(
                          padding: EdgeInsets.only(right: 10),
                          child: Chip(
                            avatar: Icon(Icons.point_of_sale, size: 18),
                            label: Text('Cash shift open'),
                          ),
                        ),
                      AnimatedBuilder(
                        animation: widget.licenseController,
                        builder: (context, _) => LicenseStatusBadge(
                          status: widget.licenseController.status,
                          isLoading: widget.licenseController.isLoading,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Lock and switch user',
                        onPressed: state.lock,
                        icon: const Icon(Icons.lock_outline),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(child: destinations[index].screen),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<_Destination> _destinations(AppState state) {
    final user = state.currentUser!;
    return [
      if (user.can(CommercialPermission.dashboardView))
        const _Destination(
          icon: Icons.dashboard_outlined,
          selectedIcon: Icons.dashboard,
          label: 'Dashboard',
          screen: DashboardScreen(),
        ),
      if (user.can(CommercialPermission.salesProcess))
        const _Destination(
          icon: Icons.point_of_sale_outlined,
          selectedIcon: Icons.point_of_sale,
          label: 'Point of sale',
          screen: PosScreen(),
        ),
      if (user.can(CommercialPermission.productsManage) ||
          user.can(CommercialPermission.stockAdjust))
        const _Destination(
          icon: Icons.inventory_2_outlined,
          selectedIcon: Icons.inventory_2,
          label: 'Products',
          screen: ProductsScreen(),
        ),
      if (user.can(CommercialPermission.debtView))
        const _Destination(
          icon: Icons.people_outline,
          selectedIcon: Icons.people,
          label: 'Customers',
          screen: ContactsScreen(type: ContactType.customer),
        ),
      if (user.can(CommercialPermission.purchasingManage))
        const _Destination(
          icon: Icons.local_shipping_outlined,
          selectedIcon: Icons.local_shipping,
          label: 'Suppliers',
          screen: ContactsScreen(type: ContactType.supplier),
        ),
      if (user.can(CommercialPermission.expensesView))
        const _Destination(
          icon: Icons.receipt_long_outlined,
          selectedIcon: Icons.receipt_long,
          label: 'Expenses',
          screen: ExpensesScreen(),
        ),
      const _Destination(
        icon: Icons.business_center_outlined,
        selectedIcon: Icons.business_center,
        label: 'Commercial Suite',
        screen: CommercialSuiteScreen(),
      ),
      if (user.can(CommercialPermission.reportsView))
        const _Destination(
          icon: Icons.analytics_outlined,
          selectedIcon: Icons.analytics,
          label: 'Reports',
          screen: ReportsScreen(),
        ),
      if (user.can(CommercialPermission.licenseManage))
        _Destination(
          icon: Icons.workspace_premium_outlined,
          selectedIcon: Icons.workspace_premium,
          label: 'Licence',
          screen: LicenseScreen(controller: widget.licenseController),
        ),
      if (user.can(CommercialPermission.settingsManage))
        const _Destination(
          icon: Icons.settings_outlined,
          selectedIcon: Icons.settings,
          label: 'Settings',
          screen: SettingsScreen(),
        ),
    ];
  }

  Widget _startupError(BuildContext context, AppState state) => Scaffold(
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

class _Destination {
  const _Destination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.screen,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final Widget screen;
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
