import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/app_role.dart';
import '../models/app_user.dart';
import '../models/brokerage.dart';
import '../models/company.dart';
import '../models/document_record.dart';
import '../models/invoice_record.dart';
import '../models/load_item.dart';
import '../services/admin_auth_service.dart';
import '../services/automation_service.dart';
import '../services/invoice_service.dart';
import '../services/realtime_service.dart';
import '../services/session_cache_service.dart';
import '../services/storage_service.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.user});

  final AppUser user;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  final RealtimeService _realtime = RealtimeService.instance;
  final InvoiceService _invoiceService = InvoiceService();
  final AutomationService _automationService = AutomationService();
  final StorageService _storageService = StorageService();
  int _currentIndex = 0;

  List<_NavItem> get _navItems {
    switch (widget.user.role) {
      case AppRole.dispatcher:
        return const [
          _NavItem('My Dashboard', Icons.dashboard_outlined),
          _NavItem('My Loads', Icons.local_shipping_outlined),
          _NavItem('Add Load', Icons.add_circle_outline),
          _NavItem('My Earnings', Icons.payments_outlined),
        ];
      case AppRole.accountant:
        return const [
          _NavItem('Accounting', Icons.analytics_outlined),
          _NavItem('Invoice Queue', Icons.receipt_long_outlined),
          _NavItem('Payments', Icons.account_balance_wallet_outlined),
        ];
      case AppRole.paperwork:
        return const [
          _NavItem('Paperwork', Icons.folder_copy_outlined),
          _NavItem('All Loads', Icons.list_alt_outlined),
          _NavItem('Missing Docs', Icons.warning_amber_outlined),
        ];
      case AppRole.admin:
        return const [
          _NavItem('Admin', Icons.space_dashboard_outlined),
          _NavItem('Loads', Icons.local_shipping_outlined),
          _NavItem('Users', Icons.groups_2_outlined),
          _NavItem('Companies', Icons.business_outlined),
          _NavItem('Brokerages', Icons.apartment_outlined),
          _NavItem('Invoices', Icons.receipt_outlined),
        ];
    }
  }

  Future<void> _signOut() async {
    await SessionCacheService.instance.clear();
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<LoadItem>>(
      stream: _realtime.streamLoadsForUser(widget.user),
      builder: (context, loadsSnapshot) {
        final loads = loadsSnapshot.data ?? const <LoadItem>[];

        return StreamBuilder<List<Company>>(
          stream: _realtime.streamCompanies(),
          builder: (context, companiesSnapshot) {
            final companies = companiesSnapshot.data ?? const <Company>[];

            return StreamBuilder<List<Brokerage>>(
              stream: _realtime.streamBrokerages(),
              builder: (context, brokerageSnapshot) {
                final brokerages =
                    brokerageSnapshot.data ?? const <Brokerage>[];

                return StreamBuilder<List<InvoiceRecord>>(
                  stream: _realtime.streamInvoices(),
                  builder: (context, invoicesSnapshot) {
                    final invoices =
                        invoicesSnapshot.data ?? const <InvoiceRecord>[];
                    final currentPage = _buildCurrentPage(
                      context,
                      loads: loads,
                      companies: companies,
                      brokerages: brokerages,
                      invoices: invoices,
                    );

                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final desktop = constraints.maxWidth >= 1100;
                        final tablet = constraints.maxWidth >= 760;

                        if (desktop) {
                          return Scaffold(
                            body: SafeArea(
                              child: Padding(
                                padding: const EdgeInsets.all(18),
                                child: Row(
                                  children: [
                                    _BrandShowcasePanel(role: widget.user.role),
                                    const SizedBox(width: 18),
                                    Expanded(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF0B1120),
                                          borderRadius: BorderRadius.circular(28),
                                          border: Border.all(
                                            color: const Color(0xFF202A43),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            _SideNav(
                                              items: _navItems,
                                              currentIndex: _currentIndex,
                                              onSelected: (index) {
                                                setState(() => _currentIndex = index);
                                              },
                                              user: widget.user,
                                              onSignOut: _signOut,
                                            ),
                                            Expanded(
                                              child: Padding(
                                                padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                                                child: Column(
                                                  children: [
                                                    _TopToolbar(
                                                      user: widget.user,
                                                      title: _navItems[_currentIndex].label,
                                                    ),
                                                    const SizedBox(height: 18),
                                                    Expanded(child: currentPage),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }

                        return Scaffold(
                          appBar: AppBar(
                            title: Text(_navItems[_currentIndex].label),
                            actions: [
                              Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: _MiniProfile(user: widget.user),
                              ),
                            ],
                          ),
                          drawer: Drawer(
                            child: SafeArea(
                              child: _SideNav(
                                items: _navItems,
                                currentIndex: _currentIndex,
                                onSelected: (index) {
                                  setState(() => _currentIndex = index);
                                  Navigator.of(context).pop();
                                },
                                user: widget.user,
                                onSignOut: _signOut,
                                compact: true,
                              ),
                            ),
                          ),
                          body: Padding(
                            padding: EdgeInsets.all(tablet ? 16 : 12),
                            child: Column(
                              children: [
                                _TopToolbar(
                                  user: widget.user,
                                  title: _navItems[_currentIndex].label,
                                  compact: true,
                                ),
                                const SizedBox(height: 14),
                                Expanded(child: currentPage),
                              ],
                            ),
                          ),
                          bottomNavigationBar: NavigationBar(
                            selectedIndex: _currentIndex,
                            onDestinationSelected: (index) {
                              setState(() => _currentIndex = index);
                            },
                            destinations: _navItems
                                .map(
                                  (item) => NavigationDestination(
                                    icon: Icon(item.icon),
                                    label: item.label,
                                  ),
                                )
                                .toList(),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildCurrentPage(
    BuildContext context, {
    required List<LoadItem> loads,
    required List<Company> companies,
    required List<Brokerage> brokerages,
    required List<InvoiceRecord> invoices,
  }) {
    switch (widget.user.role) {
      case AppRole.dispatcher:
        return switch (_currentIndex) {
          0 => _DispatcherDashboard(
              user: widget.user,
              loads: loads,
              companies: companies,
            ),
          1 => _LoadsListPage(
              user: widget.user,
              loads: loads,
              onOpen: _openLoadDetails,
            ),
          2 => _LoadCreatePage(
              user: widget.user,
              companies: companies,
              brokerages: brokerages,
              onCreated: (message) => _showMessage(message),
            ),
          _ => _DispatcherEarningsPage(
              loads: loads,
              companies: companies,
            ),
        };
      case AppRole.accountant:
        return switch (_currentIndex) {
          0 => _AccountantDashboard(
              loads: loads,
              invoices: invoices,
            ),
          1 => _InvoiceQueuePage(
              loads: loads.where((load) => load.invoiceReady).toList(),
              onGenerate: _generateInvoice,
              onOpen: _openLoadDetails,
            ),
          _ => _PaymentsPage(
              invoices: invoices,
              onMarkPaid: _markInvoicePaid,
            ),
        };
      case AppRole.paperwork:
        return switch (_currentIndex) {
          0 => _PaperworkDashboard(loads: loads),
          1 => _LoadsListPage(
              user: widget.user,
              loads: loads,
              onOpen: _openLoadDetails,
            ),
          _ => _LoadsListPage(
              user: widget.user,
              loads: loads
                  .where((load) => load.missingDocumentsCount > 0)
                  .toList(),
              onOpen: _openLoadDetails,
              emptyLabel: 'No missing-document alerts right now.',
            ),
        };
      case AppRole.admin:
        return switch (_currentIndex) {
          0 => _AdminDashboard(loads: loads, invoices: invoices),
          1 => _LoadsListPage(
              user: widget.user,
              loads: loads,
              onOpen: _openLoadDetails,
            ),
          2 => _UsersPage(onMessage: _showMessage),
          3 => _CompaniesPage(
              companies: companies,
              onMessage: _showMessage,
            ),
          4 => _BrokeragesPage(
              brokerages: brokerages,
              onMessage: _showMessage,
            ),
          _ => _PaymentsPage(
              invoices: invoices,
              onMarkPaid: _markInvoicePaid,
            ),
        };
    }
  }

  Future<void> _generateInvoice(LoadItem load) async {
    try {
      final result = await _automationService.generateInvoice(load.id);
      final invoiceNumber = (result['invoiceNumber'] ?? '').toString();
      if (invoiceNumber.isNotEmpty) {
        _showMessage('Generated $invoiceNumber');
        return;
      }
      final invoice = await _invoiceService.generateInvoice(load);
      _showMessage('Generated ${invoice.invoiceNumber} locally');
    } catch (e) {
      try {
        final invoice = await _invoiceService.generateInvoice(load);
        _showMessage('Generated ${invoice.invoiceNumber} locally');
      } catch (fallbackError) {
        _showMessage(fallbackError.toString());
      }
    }
  }

  Future<void> _markInvoicePaid(InvoiceRecord invoice) async {
    await _realtime.saveInvoice(
      InvoiceRecord(
        id: invoice.id,
        invoiceNumber: invoice.invoiceNumber,
        loadId: invoice.loadId,
        companyName: invoice.companyName,
        invoiceDate: invoice.invoiceDate,
        feePercentage: invoice.feePercentage,
        dispatchFeeAmount: invoice.dispatchFeeAmount,
        invoiceAmount: invoice.invoiceAmount,
        dueDate: invoice.dueDate,
        invoiceFileUrl: invoice.invoiceFileUrl,
        storagePath: invoice.storagePath,
        invoiceStatus: invoice.invoiceStatus,
        paymentStatus: 'Paid',
        sentDate: invoice.sentDate,
        paidDate: DateTime.now().toIso8601String(),
        notes: invoice.notes,
      ),
    );
    _showMessage('${invoice.invoiceNumber} marked paid');
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _openLoadDetails(LoadItem load) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return _LoadDetailSheet(
          user: widget.user,
          load: load,
          onUpdated: _showMessage,
          onGenerateInvoice:
              widget.user.isAccountant || widget.user.isAdmin ? _generateInvoice : null,
          storageService: _storageService,
        );
      },
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;

  const _NavItem(this.label, this.icon);
}

class _BrandShowcasePanel extends StatelessWidget {
  const _BrandShowcasePanel({required this.role});

  final AppRole role;

  @override
  Widget build(BuildContext context) {
    final features = switch (role) {
      AppRole.dispatcher => const [
          'Role-based dashboards',
          'Load management',
          'Document & paperwork',
          'Revenue analytics',
        ],
      AppRole.accountant => const [
          'Invoice automation',
          'Payment tracking',
          'Aging visibility',
          'Billing reports',
        ],
      AppRole.paperwork => const [
          'Missing-doc alerts',
          'POD/BOL upload',
          'Verification flow',
          'Completion dashboard',
        ],
      AppRole.admin => const [
          'Management overview',
          'Dispatcher summary',
          'Company controls',
          'System reporting',
        ],
    };

    return Container(
      width: 280,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFF0C1021), Color(0xFF131B34)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: Border.all(color: const Color(0xFF202A43)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.local_shipping, color: Color(0xFF8B6BFF)),
              SizedBox(width: 10),
              Text(
                'DISPATCH FLOW',
                style: TextStyle(
                  color: Color(0xFFA78BFA),
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Text(
            'Dispatch\nManagement\nSystem',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Smarter dispatch operations with live visibility, cleaner paperwork flow, and sharper revenue insights.',
            style: TextStyle(color: Color(0xFF96A2C0), height: 1.5),
          ),
          const SizedBox(height: 28),
          const Text(
            'KEY FEATURES',
            style: TextStyle(
              color: Color(0xFF7C87A6),
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 14),
          ...features.map(
            (feature) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A2340),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.check_circle_outline,
                      size: 18,
                      color: Color(0xFF8B6BFF),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      feature,
                      style: const TextStyle(color: Color(0xFFD6DDF0)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                colors: [Color(0xFF24175A), Color(0xFF171D35)],
              ),
              border: Border.all(color: const Color(0xFF2F3A5C)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Realtime. Role-aware. Revenue-driven.',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 8),
                Text(
                  'A single command center for dispatch, paperwork, accounting, and admin.',
                  style: TextStyle(color: Color(0xFF9AA7C7), height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SideNav extends StatelessWidget {
  const _SideNav({
    required this.items,
    required this.currentIndex,
    required this.onSelected,
    required this.user,
    required this.onSignOut,
    this.compact = false,
  });

  final List<_NavItem> items;
  final int currentIndex;
  final ValueChanged<int> onSelected;
  final AppUser user;
  final Future<void> Function() onSignOut;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: compact ? double.infinity : 220,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: compact ? Colors.transparent : const Color(0xFF0F1528),
        borderRadius: compact
            ? null
            : const BorderRadius.only(
                topLeft: Radius.circular(28),
                bottomLeft: Radius.circular(28),
              ),
        border: compact
            ? null
            : const Border(
                right: BorderSide(color: Color(0xFF202A43)),
              ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!compact) ...[
            const Text(
              'Dispatch Flow',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 20),
          ],
          ...List.generate(items.length, (index) {
            final item = items[index];
            final selected = index == currentIndex;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => onSelected(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: selected
                        ? const Color(0xFF6C4DFF)
                        : const Color(0x00000000),
                    border: Border.all(
                      color: selected
                          ? const Color(0xFF6C4DFF)
                          : const Color(0xFF1F2942),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(item.icon, size: 18),
                      const SizedBox(width: 12),
                      Expanded(child: Text(item.label)),
                    ],
                  ),
                ),
              ),
            );
          }),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF121A31),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF1F2942)),
            ),
            child: Row(
              children: [
                _MiniProfile(user: user),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        user.role.label,
                        style: const TextStyle(
                          color: Color(0xFF95A2C1),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onSignOut,
                  icon: const Icon(Icons.logout, size: 18),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopToolbar extends StatelessWidget {
  const _TopToolbar({
    required this.user,
    required this.title,
    this.compact = false,
  });

  final AppUser user;
  final String title;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1528),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF202A43)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: compact
                    ? 'Search loads...'
                    : 'Search loads, drivers, brokerages...',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                filled: true,
                fillColor: const Color(0xFF0B1120),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFF24314B)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          if (!compact) ...[
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.notifications_none),
            ),
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.help_outline),
            ),
          ],
          const SizedBox(width: 8),
          _MiniProfile(user: user),
          if (!compact) ...[
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  user.role.label,
                  style: const TextStyle(color: Color(0xFF95A2C1), fontSize: 12),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniProfile extends StatelessWidget {
  const _MiniProfile({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final name = user.name.trim().isEmpty ? user.email : user.name;
    final parts = name.split(' ').where((part) => part.isNotEmpty).toList();
    final initials = parts.isEmpty
        ? 'U'
        : parts.take(2).map((part) => part[0].toUpperCase()).join();

    return Container(
      width: 40,
      height: 40,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFF6C4DFF), Color(0xFF19D3C5)],
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _DispatcherDashboard extends StatelessWidget {
  const _DispatcherDashboard({
    required this.user,
    required this.loads,
    required this.companies,
  });

  final AppUser user;
  final List<LoadItem> loads;
  final List<Company> companies;

  @override
  Widget build(BuildContext context) {
    final delivered = loads.where((load) => load.status == 'Delivered').length;
    final active = loads.where((load) => load.status != 'Delivered').length;
    final totalRevenue =
        loads.fold<double>(0, (sum, load) => sum + load.dispatcherRevenue);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _PageHero(
          title: 'Welcome back, ${user.name.split(' ').first}',
          subtitle: 'Here is what is happening with your dispatch operation today.',
          actionLabel: 'This Month',
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _SummaryCard(title: 'My Loads', value: '${loads.length}', icon: Icons.local_shipping_outlined),
            _SummaryCard(title: 'Delivered', value: '$delivered', icon: Icons.check_circle_outline),
            _SummaryCard(title: 'Active', value: '$active', icon: Icons.timelapse_outlined),
            _SummaryCard(title: 'Revenue', value: _money(totalRevenue), icon: Icons.attach_money_outlined),
          ],
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < 980;
            if (stacked) {
              return Column(
                children: [
                  _SectionCard(
                    title: 'Revenue by Company',
                    actionLabel: 'View Details',
                    child: SizedBox(
                      height: 240,
                      child: _RevenueByCompanyChart(loads: loads, companies: companies),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SectionCard(
                    title: 'Loads Status',
                    actionLabel: 'View All Loads',
                    child: _LoadStatusBreakdown(loads: loads),
                  ),
                  const SizedBox(height: 16),
                  _SectionCard(
                    title: 'Recent Loads',
                    actionLabel: 'View All',
                    child: _RecentLoadsPanel(loads: loads),
                  ),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 4,
                  child: _SectionCard(
                    title: 'Revenue by Company',
                    actionLabel: 'View Details',
                    child: SizedBox(
                      height: 240,
                      child: _RevenueByCompanyChart(loads: loads, companies: companies),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 3,
                  child: _SectionCard(
                    title: 'Loads Status',
                    actionLabel: 'View All Loads',
                    child: _LoadStatusBreakdown(loads: loads),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 4,
                  child: _SectionCard(
                    title: 'Recent Loads',
                    actionLabel: 'View All',
                    child: _RecentLoadsPanel(loads: loads),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Monthly Performance',
          child: SizedBox(
            height: 260,
            child: _MonthlyPerformanceLineChart(loads: loads),
          ),
        ),
      ],
    );
  }
}

class _DispatcherEarningsPage extends StatelessWidget {
  const _DispatcherEarningsPage({
    required this.loads,
    required this.companies,
  });

  final List<LoadItem> loads;
  final List<Company> companies;

  @override
  Widget build(BuildContext context) {
    final total = loads.fold<double>(0, (sum, load) => sum + load.dispatcherRevenue);
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final daily = loads
        .where((load) => load.date == today)
        .fold<double>(0, (sum, load) => sum + load.dispatcherRevenue);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _PageHero(
          title: 'Accounting Dashboard',
          subtitle: 'Monitor invoicing, receivables, and company billing performance.',
          actionLabel: 'This Month',
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _SummaryCard(title: 'Today', value: _money(daily), icon: Icons.today_outlined),
            _SummaryCard(title: 'Total', value: _money(total), icon: Icons.paid_outlined),
            _SummaryCard(
              title: 'Delivered Loads',
              value: '${loads.where((load) => load.status == 'Delivered').length}',
              icon: Icons.inventory_2_outlined,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Load Status Breakdown',
          child: SizedBox(height: 220, child: _StatusPieChart(loads: loads)),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Earnings by Company',
          child: SizedBox(
            height: 240,
            child: _RevenueByCompanyChart(loads: loads, companies: companies),
          ),
        ),
      ],
    );
  }
}

class _AccountantDashboard extends StatelessWidget {
  const _AccountantDashboard({
    required this.loads,
    required this.invoices,
  });

  final List<LoadItem> loads;
  final List<InvoiceRecord> invoices;

  @override
  Widget build(BuildContext context) {
    final generated = invoices.length;
    final unpaid = invoices.where((invoice) => invoice.paymentStatus != 'Paid').length;
    final receivables = invoices
        .where((invoice) => invoice.paymentStatus != 'Paid')
        .fold<double>(0, (sum, invoice) => sum + invoice.invoiceAmount);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _SummaryCard(title: 'Invoices', value: '$generated', icon: Icons.receipt_long_outlined),
            _SummaryCard(title: 'Unpaid', value: '$unpaid', icon: Icons.warning_amber_outlined),
            _SummaryCard(title: 'Receivables', value: _money(receivables), icon: Icons.account_balance_outlined),
            _SummaryCard(
              title: 'Invoice Queue',
              value: '${loads.where((load) => load.invoiceReady).length}',
              icon: Icons.pending_actions_outlined,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Invoices Generated by Month',
          actionLabel: 'View Report',
          child: SizedBox(height: 240, child: _InvoiceMonthlyChart(invoices: invoices)),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 840) {
              return Column(
                children: [
                  _SectionCard(
                    title: 'Paid vs Unpaid',
                    child: SizedBox(height: 220, child: _PaymentStatusDonut(invoices: invoices)),
                  ),
                  const SizedBox(height: 16),
                  _SectionCard(
                    title: 'Billing by Company',
                    child: SizedBox(height: 220, child: _BillingByCompanyChart(invoices: invoices)),
                  ),
                ],
              );
            }
            return Row(
              children: [
                Expanded(
                  child: _SectionCard(
                    title: 'Paid vs Unpaid',
                    child: SizedBox(height: 220, child: _PaymentStatusDonut(invoices: invoices)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _SectionCard(
                    title: 'Billing by Company',
                    child: SizedBox(height: 220, child: _BillingByCompanyChart(invoices: invoices)),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _PaperworkDashboard extends StatelessWidget {
  const _PaperworkDashboard({required this.loads});

  final List<LoadItem> loads;

  @override
  Widget build(BuildContext context) {
    final missingPod = loads.where((load) => !load.podUploaded).length;
    final missingBol = loads.where((load) => !load.bolUploaded).length;
    final missingRc =
        loads.where((load) => !load.rateConfirmationUploaded).length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _PageHero(
          title: 'Paperwork Dashboard',
          subtitle: 'Track upload completeness and clear missing-document alerts faster.',
          actionLabel: 'Operational View',
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _SummaryCard(title: 'Missing PODs', value: '$missingPod', icon: Icons.description_outlined),
            _SummaryCard(title: 'Missing BOLs', value: '$missingBol', icon: Icons.assignment_late_outlined),
            _SummaryCard(title: 'Missing RCs', value: '$missingRc', icon: Icons.error_outline),
            _SummaryCard(
              title: 'Complete Loads',
              value: '${loads.where((load) => load.paperworkComplete).length}',
              icon: Icons.task_alt_outlined,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Paperwork Completion',
          child: SizedBox(height: 220, child: _PaperworkPieChart(loads: loads)),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 840) {
              return Column(
                children: [
                  _SectionCard(
                    title: 'Missing Documents',
                    child: SizedBox(height: 220, child: _MissingDocumentsBar(loads: loads)),
                  ),
                  const SizedBox(height: 16),
                  _SectionCard(
                    title: 'Attention Required',
                    child: _MissingDocsList(loads: loads),
                  ),
                ],
              );
            }
            return Row(
              children: [
                Expanded(
                  child: _SectionCard(
                    title: 'Missing Documents',
                    child: SizedBox(height: 220, child: _MissingDocumentsBar(loads: loads)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _SectionCard(
                    title: 'Attention Required',
                    child: _MissingDocsList(loads: loads),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _AdminDashboard extends StatelessWidget {
  const _AdminDashboard({
    required this.loads,
    required this.invoices,
  });

  final List<LoadItem> loads;
  final List<InvoiceRecord> invoices;

  @override
  Widget build(BuildContext context) {
    final gross =
        loads.fold<double>(0, (sum, load) => sum + load.loadRate);
    final fees =
        loads.fold<double>(0, (sum, load) => sum + load.dispatchFeeAmount);
    final unpaid = invoices
        .where((invoice) => invoice.paymentStatus != 'Paid')
        .fold<double>(0, (sum, invoice) => sum + invoice.invoiceAmount);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _PageHero(
          title: 'Admin Dashboard',
          subtitle: 'Monitor revenue, dispatcher performance, paperwork health, and outstanding payments.',
          actionLabel: 'This Month',
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _SummaryCard(title: 'Total Loads', value: '${loads.length}', icon: Icons.list_alt_outlined),
            _SummaryCard(title: 'Gross Volume', value: _money(gross), icon: Icons.bar_chart_outlined),
            _SummaryCard(title: 'Dispatch Fees', value: _money(fees), icon: Icons.attach_money_outlined),
            _SummaryCard(title: 'Outstanding', value: _money(unpaid), icon: Icons.pending_outlined),
          ],
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Delivered vs Active Loads',
          child: SizedBox(height: 220, child: _StatusPieChart(loads: loads)),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Dispatch Fee Income by Company',
          child: SizedBox(height: 240, child: _CompanyFeeChart(loads: loads)),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 980) {
              return Column(
                children: [
                  _SectionCard(
                    title: 'Dispatcher Performance',
                    actionLabel: 'View All Dispatchers',
                    child: SizedBox(height: 240, child: _DispatcherComparisonChart(loads: loads)),
                  ),
                  const SizedBox(height: 16),
                  _SectionCard(
                    title: 'Paperwork Status',
                    child: SizedBox(height: 240, child: _PaperworkPieChart(loads: loads)),
                  ),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 5,
                  child: _SectionCard(
                    title: 'Dispatcher Performance',
                    actionLabel: 'View All Dispatchers',
                    child: SizedBox(height: 240, child: _DispatcherComparisonChart(loads: loads)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 3,
                  child: _SectionCard(
                    title: 'Paperwork Status',
                    child: SizedBox(height: 240, child: _PaperworkPieChart(loads: loads)),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _LoadsListPage extends StatelessWidget {
  const _LoadsListPage({
    required this.user,
    required this.loads,
    required this.onOpen,
    this.emptyLabel = 'No loads available.',
  });

  final AppUser user;
  final List<LoadItem> loads;
  final Future<void> Function(LoadItem load) onOpen;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    if (loads.isEmpty) {
      return Center(child: Text(emptyLabel));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final load = loads[index];
        return Card(
          child: ListTile(
            title: Text('${load.loadNumber} • ${load.routeSummary}'),
            subtitle: Text(
              '${load.companyName} • ${load.driverName} • ${load.status}\n'
              'Fee: ${_money(load.dispatchFeeAmount)} • Invoice: ${load.invoiceStatus} • Paperwork: ${load.paperworkStatus}',
            ),
            isThreeLine: true,
            trailing: const Icon(Icons.chevron_right),
            onTap: () => onOpen(load),
          ),
        );
      },
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemCount: loads.length,
    );
  }
}

class _LoadCreatePage extends StatefulWidget {
  const _LoadCreatePage({
    required this.user,
    required this.companies,
    required this.brokerages,
    required this.onCreated,
  });

  final AppUser user;
  final List<Company> companies;
  final List<Brokerage> brokerages;
  final void Function(String message) onCreated;

  @override
  State<_LoadCreatePage> createState() => _LoadCreatePageState();
}

class _LoadCreatePageState extends State<_LoadCreatePage> {
  final _formKey = GlobalKey<FormState>();
  final _loadNumber = TextEditingController();
  final _driverName = TextEditingController();
  final _driverPhone = TextEditingController();
  final _truckNumber = TextEditingController();
  final _pickup = TextEditingController();
  final _delivery = TextEditingController();
  final _brokerContact = TextEditingController();
  final _rate = TextEditingController();
  final _notes = TextEditingController();
  Company? _company;
  Brokerage? _brokerage;
  bool _saving = false;

  @override
  void dispose() {
    _loadNumber.dispose();
    _driverName.dispose();
    _driverPhone.dispose();
    _truckNumber.dispose();
    _pickup.dispose();
    _delivery.dispose();
    _brokerContact.dispose();
    _rate.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_company == null || _brokerage == null) {
      widget.onCreated('Select a company and brokerage first.');
      return;
    }

    setState(() => _saving = true);
    try {
      final exists = await RealtimeService.instance
          .loadNumberExists(_loadNumber.text.trim());
      if (exists) {
        widget.onCreated('Load number must be unique.');
        return;
      }

      final driverId = await RealtimeService.instance.upsertDriver(
        name: _driverName.text.trim(),
        truckNumber: _truckNumber.text.trim(),
        phone: _driverPhone.text.trim(),
      );

      final rate = double.tryParse(_rate.text.trim()) ?? 0;
      final feePercentage = _company!.feePercentage;
      final dispatchFeeAmount = rate * (feePercentage / 100);
      final now = DateTime.now().toIso8601String();
      final loadId = RealtimeService.instance.loadsRef.push().key!;
      final load = LoadItem(
        id: loadId,
        loadNumber: _loadNumber.text.trim(),
        date: DateFormat('yyyy-MM-dd').format(DateTime.now()),
        companyId: _company!.id,
        companyName: _company!.name,
        dispatcherId: widget.user.dispatcherId,
        dispatcherName: widget.user.name,
        dispatcherEmail: widget.user.email,
        driverId: driverId,
        driverName: _driverName.text.trim(),
        truckNumber: _truckNumber.text.trim(),
        pickupLocation: _pickup.text.trim(),
        deliveryLocation: _delivery.text.trim(),
        routeSummary: '${_pickup.text.trim()} to ${_delivery.text.trim()}',
        brokerageId: _brokerage!.id,
        brokerageName: _brokerage!.name,
        brokerageMc: _brokerage!.mc,
        brokerContact: _brokerContact.text.trim(),
        loadRate: rate,
        feePercentage: feePercentage,
        dispatchFeeAmount: dispatchFeeAmount,
        dispatcherRevenue: dispatchFeeAmount,
        status: 'Active',
        invoiceStatus: 'Pending',
        paymentStatus: 'Unpaid',
        paperworkStatus: 'Incomplete',
        notes: _notes.text.trim(),
        createdBy: widget.user.uid,
        createdDate: now,
        updatedDate: now,
        rateConfirmationUploaded: false,
        podUploaded: false,
        bolUploaded: false,
        missingDocumentsCount: 3,
      );

      await RealtimeService.instance.saveLoad(load);
      _formKey.currentState!.reset();
      _loadNumber.clear();
      _driverName.clear();
      _driverPhone.clear();
      _truckNumber.clear();
      _pickup.clear();
      _delivery.clear();
      _brokerContact.clear();
      _rate.clear();
      _notes.clear();
      setState(() {
        _company = null;
        _brokerage = null;
      });
      widget.onCreated('Load ${load.loadNumber} created successfully.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Create New Load',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _loadNumber,
                    decoration: const InputDecoration(labelText: 'Load Number'),
                    validator: (value) =>
                        value == null || value.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<Company>(
                    initialValue: _company,
                    items: widget.companies
                        .where((company) => company.active)
                        .map(
                          (company) => DropdownMenuItem(
                            value: company,
                            child: Text(
                              '${company.name} (${company.feePercentage.toStringAsFixed(2)}%)',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (company) => setState(() => _company = company),
                    decoration: const InputDecoration(labelText: 'Company'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<Brokerage>(
                    initialValue: _brokerage,
                    items: widget.brokerages
                        .map(
                          (brokerage) => DropdownMenuItem(
                            value: brokerage,
                            child: Text('${brokerage.name} • ${brokerage.mc}'),
                          ),
                        )
                        .toList(),
                    onChanged: (brokerage) =>
                        setState(() => _brokerage = brokerage),
                    decoration: const InputDecoration(labelText: 'Brokerage'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _driverName,
                    decoration: const InputDecoration(labelText: 'Driver Name'),
                    validator: (value) =>
                        value == null || value.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _driverPhone,
                    decoration: const InputDecoration(labelText: 'Driver Phone'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _truckNumber,
                    decoration: const InputDecoration(labelText: 'Truck Number'),
                    validator: (value) =>
                        value == null || value.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _pickup,
                    decoration:
                        const InputDecoration(labelText: 'Pickup Location'),
                    validator: (value) =>
                        value == null || value.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _delivery,
                    decoration:
                        const InputDecoration(labelText: 'Delivery Location'),
                    validator: (value) =>
                        value == null || value.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _brokerContact,
                    decoration:
                        const InputDecoration(labelText: 'Broker Contact'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _rate,
                    decoration: InputDecoration(
                      labelText: 'Load Rate',
                      helperText: _company == null
                          ? 'Select company to auto-apply fee percentage'
                          : 'Fee auto-applied: ${_company!.feePercentage.toStringAsFixed(2)}%',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) =>
                        (double.tryParse(value ?? '') ?? 0) <= 0 ? 'Enter a valid amount' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _notes,
                    decoration: const InputDecoration(labelText: 'Notes'),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const CircularProgressIndicator()
                        : const Text('Create load'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _InvoiceQueuePage extends StatelessWidget {
  const _InvoiceQueuePage({
    required this.loads,
    required this.onGenerate,
    required this.onOpen,
  });

  final List<LoadItem> loads;
  final Future<void> Function(LoadItem load) onGenerate;
  final Future<void> Function(LoadItem load) onOpen;

  @override
  Widget build(BuildContext context) {
    if (loads.isEmpty) {
      return const Center(
        child: Text('No invoice-ready loads yet. Delivered loads stay here only after required paperwork is complete.'),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: loads.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final load = loads[index];
        return Card(
          child: ListTile(
            title: Text('${load.loadNumber} • ${load.companyName}'),
            subtitle: Text(
              '${load.routeSummary}\nInvoice Amount: ${_money(load.dispatcherRevenue)} • Paperwork: ${load.paperworkStatus}',
            ),
            isThreeLine: true,
            onTap: () => onOpen(load),
            trailing: ElevatedButton(
              onPressed: () => onGenerate(load),
              child: const Text('Generate'),
            ),
          ),
        );
      },
    );
  }
}

class _PaymentsPage extends StatelessWidget {
  const _PaymentsPage({
    required this.invoices,
    required this.onMarkPaid,
  });

  final List<InvoiceRecord> invoices;
  final Future<void> Function(InvoiceRecord invoice) onMarkPaid;

  @override
  Widget build(BuildContext context) {
    if (invoices.isEmpty) {
      return const Center(child: Text('No invoices yet.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: invoices.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final invoice = invoices[index];
        return Card(
          child: ListTile(
            title: Text('${invoice.invoiceNumber} • ${invoice.companyName}'),
            subtitle: Text(
              'Amount: ${_money(invoice.invoiceAmount)} • Status: ${invoice.paymentStatus}\nDue: ${invoice.dueDate}',
            ),
            isThreeLine: true,
            trailing: invoice.paymentStatus == 'Paid'
                ? const Chip(label: Text('Paid'))
                : ElevatedButton(
                    onPressed: () => onMarkPaid(invoice),
                    child: const Text('Mark Paid'),
                  ),
          ),
        );
      },
    );
  }
}

class _UsersPage extends StatelessWidget {
  const _UsersPage({required this.onMessage});

  final void Function(String message) onMessage;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AppUser>>(
      stream: RealtimeService.instance.streamUsers(),
      builder: (context, snapshot) {
        final users = snapshot.data ?? const <AppUser>[];
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await showDialog<void>(
                    context: context,
                    builder: (context) => _UserFormDialog(onMessage: onMessage),
                  );
                },
                icon: const Icon(Icons.person_add_alt_1_outlined),
                label: const Text('Create user'),
              ),
            ),
            const SizedBox(height: 12),
            ...users.map(
              (user) => Card(
                child: ListTile(
                  title: Text(user.name),
                  subtitle: Text(user.email),
                  trailing: Text(user.role.label),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CompaniesPage extends StatelessWidget {
  const _CompaniesPage({
    required this.companies,
    required this.onMessage,
  });

  final List<Company> companies;
  final void Function(String message) onMessage;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton.icon(
            onPressed: () async {
              await showDialog<void>(
                context: context,
                builder: (context) => _CompanyFormDialog(onMessage: onMessage),
              );
            },
            icon: const Icon(Icons.add_business_outlined),
            label: const Text('Add company'),
          ),
        ),
        const SizedBox(height: 12),
        ...companies.map(
          (company) => Card(
            child: ListTile(
              title: Text(company.name),
              subtitle: Text(
                'Fee: ${company.feePercentage.toStringAsFixed(2)}% • Billing: ${company.billingEmail}',
              ),
              trailing: Text(company.active ? 'Active' : 'Inactive'),
            ),
          ),
        ),
      ],
    );
  }
}

class _BrokeragesPage extends StatelessWidget {
  const _BrokeragesPage({
    required this.brokerages,
    required this.onMessage,
  });

  final List<Brokerage> brokerages;
  final void Function(String message) onMessage;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton.icon(
            onPressed: () async {
              await showDialog<void>(
                context: context,
                builder: (context) => _BrokerageFormDialog(onMessage: onMessage),
              );
            },
            icon: const Icon(Icons.add_business_outlined),
            label: const Text('Add brokerage'),
          ),
        ),
        const SizedBox(height: 12),
        ...brokerages.map(
          (brokerage) => Card(
            child: ListTile(
              title: Text(brokerage.name),
              subtitle: Text('MC: ${brokerage.mc}'),
              trailing: Text(brokerage.contact),
            ),
          ),
        ),
      ],
    );
  }
}

class _LoadDetailSheet extends StatelessWidget {
  const _LoadDetailSheet({
    required this.user,
    required this.load,
    required this.onUpdated,
    required this.storageService,
    this.onGenerateInvoice,
  });

  final AppUser user;
  final LoadItem load;
  final void Function(String message) onUpdated;
  final Future<void> Function(LoadItem load)? onGenerateInvoice;
  final StorageService storageService;

  bool get _canManageDocs => user.isPaperwork || user.isAdmin;
  bool get _canManageAccountingDocs => user.isAccountant || user.isAdmin;

  Future<void> _uploadDocument(
    BuildContext context, {
    required String documentType,
  }) async {
    final result = await FilePicker.pickFiles(
      withData: false,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );
    if (result == null || result.files.single.path == null) return;

    final file = File(result.files.single.path!);
    final folderName = documentType.toLowerCase().replaceAll(' ', '_');
    final storagePath = 'loads/${load.id}/$folderName/${result.files.single.name}';

    final upload = await storageService.uploadFile(file, storagePath);
    final documentId = RealtimeService.instance.documentsRef.push().key!;
    final document = DocumentRecord(
      id: documentId,
      loadId: load.id,
      documentType: documentType,
      fileName: upload.fileName,
      storagePath: upload.storagePath,
      downloadUrl: upload.downloadUrl,
      uploadedBy: user.uid,
      uploadedAt: DateTime.now().toIso8601String(),
      verified: false,
      notes: '',
    );
    await RealtimeService.instance.saveDocument(document);
    onUpdated('$documentType uploaded for ${load.loadNumber}');
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final accountingDocTypes = const ['Invoice Copy', 'Payment Support Document'];
    final paperworkDocTypes = const ['Rate Confirmation', 'POD', 'BOL', 'Carrier Packet', 'Other'];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(load.loadNumber, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text('${load.routeSummary} • ${load.companyName}'),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(label: Text('Status: ${load.status}')),
                  Chip(label: Text('Invoice: ${load.invoiceStatus}')),
                  Chip(label: Text('Payment: ${load.paymentStatus}')),
                  Chip(label: Text('Paperwork: ${load.paperworkStatus}')),
                ],
              ),
              const SizedBox(height: 16),
              Text('Dispatch Fee: ${_money(load.dispatchFeeAmount)}'),
              Text('Dispatcher Revenue: ${_money(load.dispatcherRevenue)}'),
              Text('Broker Contact: ${load.brokerContact.isEmpty ? 'N/A' : load.brokerContact}'),
              const SizedBox(height: 20),
              if (onGenerateInvoice != null && load.invoiceReady)
                ElevatedButton.icon(
                  onPressed: () => onGenerateInvoice!(load),
                  icon: const Icon(Icons.receipt_long_outlined),
                  label: const Text('Generate Invoice'),
                ),
              if (_canManageDocs || _canManageAccountingDocs)
                const SizedBox(height: 12),
              if (_canManageDocs)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: paperworkDocTypes
                      .map(
                        (type) => OutlinedButton(
                          onPressed: () => _uploadDocument(context, documentType: type),
                          child: Text('Upload $type'),
                        ),
                      )
                      .toList(),
                ),
              if (_canManageAccountingDocs)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: accountingDocTypes
                        .map(
                          (type) => OutlinedButton(
                            onPressed: () => _uploadDocument(context, documentType: type),
                            child: Text('Upload $type'),
                          ),
                        )
                        .toList(),
                  ),
                ),
              const SizedBox(height: 20),
              Text('Documents', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              StreamBuilder<List<DocumentRecord>>(
                stream: RealtimeService.instance.streamDocumentsForLoad(load.id),
                builder: (context, snapshot) {
                  final documents = snapshot.data ?? const <DocumentRecord>[];
                  if (documents.isEmpty) {
                    return const Text('No documents uploaded yet.');
                  }

                  return Column(
                    children: documents
                        .map(
                          (document) => Card(
                            child: ListTile(
                              title: Text(document.documentType),
                              subtitle: Text(
                                '${document.fileName}\nUploaded: ${document.uploadedAt}',
                              ),
                              isThreeLine: true,
                              trailing: _canManageDocs
                                  ? Checkbox(
                                      value: document.verified,
                                      onChanged: (value) async {
                                        await RealtimeService.instance
                                            .setDocumentVerification(
                                          document.id,
                                          verified: value ?? false,
                                        );
                                        onUpdated(
                                          '${document.documentType} verification updated.',
                                        );
                                      },
                                    )
                                  : null,
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserFormDialog extends StatefulWidget {
  const _UserFormDialog({required this.onMessage});

  final void Function(String message) onMessage;

  @override
  State<_UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<_UserFormDialog> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  AppRole _role = AppRole.dispatcher;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final credential = await AdminAuthService.createUser(
        _email.text.trim(),
        _password.text.trim(),
      );
      final role = _role;
      final dispatcherId =
          role == AppRole.dispatcher ? 'disp_${DateTime.now().millisecondsSinceEpoch}' : '';
      final user = AppUser(
        uid: credential.user!.uid,
        name: _name.text.trim(),
        email: _email.text.trim(),
        role: role,
        dispatcherId: dispatcherId,
        active: true,
      );
      await RealtimeService.instance.saveUser(user);
      widget.onMessage('${role.label} account created.');
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      widget.onMessage('User creation failed: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create User'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 12),
            TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email')),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<AppRole>(
              initialValue: _role,
              items: AppRole.values
                  .map(
                    (role) => DropdownMenuItem(
                      value: role,
                      child: Text(role.label),
                    ),
                  )
                  .toList(),
              onChanged: (role) => setState(() => _role = role ?? AppRole.dispatcher),
              decoration: const InputDecoration(labelText: 'Role'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: _saving ? const CircularProgressIndicator() : const Text('Create'),
        ),
      ],
    );
  }
}

class _CompanyFormDialog extends StatefulWidget {
  const _CompanyFormDialog({required this.onMessage});

  final void Function(String message) onMessage;

  @override
  State<_CompanyFormDialog> createState() => _CompanyFormDialogState();
}

class _CompanyFormDialogState extends State<_CompanyFormDialog> {
  final _name = TextEditingController();
  final _fee = TextEditingController();
  final _email = TextEditingController();
  final _terms = TextEditingController(text: 'Net 15');
  final _notes = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _fee.dispose();
    _email.dispose();
    _terms.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final id = RealtimeService.instance.companiesRef.push().key!;
    final company = Company(
      id: id,
      name: _name.text.trim(),
      feePercentage: double.tryParse(_fee.text.trim()) ?? 0,
      billingEmail: _email.text.trim(),
      billingTerms: _terms.text.trim(),
      active: true,
      notes: _notes.text.trim(),
    );
    await RealtimeService.instance.saveCompany(company);
    widget.onMessage('${company.name} added.');
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Company'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Company Name')),
            const SizedBox(height: 12),
            TextField(controller: _fee, decoration: const InputDecoration(labelText: 'Dispatch Fee %')),
            const SizedBox(height: 12),
            TextField(controller: _email, decoration: const InputDecoration(labelText: 'Billing Email')),
            const SizedBox(height: 12),
            TextField(controller: _terms, decoration: const InputDecoration(labelText: 'Billing Terms')),
            const SizedBox(height: 12),
            TextField(controller: _notes, decoration: const InputDecoration(labelText: 'Notes')),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ElevatedButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

class _BrokerageFormDialog extends StatefulWidget {
  const _BrokerageFormDialog({required this.onMessage});

  final void Function(String message) onMessage;

  @override
  State<_BrokerageFormDialog> createState() => _BrokerageFormDialogState();
}

class _BrokerageFormDialogState extends State<_BrokerageFormDialog> {
  final _name = TextEditingController();
  final _mc = TextEditingController();
  final _contact = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _mc.dispose();
    _contact.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final id = RealtimeService.instance.brokeragesRef.push().key!;
    final brokerage = Brokerage(
      id: id,
      name: _name.text.trim(),
      mc: _mc.text.trim(),
      contact: _contact.text.trim(),
    );
    await RealtimeService.instance.saveBrokerage(brokerage);
    widget.onMessage('${brokerage.name} added.');
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Brokerage'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name')),
          const SizedBox(height: 12),
          TextField(controller: _mc, decoration: const InputDecoration(labelText: 'MC')),
          const SizedBox(height: 12),
          TextField(controller: _contact, decoration: const InputDecoration(labelText: 'Contact')),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ElevatedButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF171F38), Color(0xFF22175A)],
                  ),
                ),
                child: Icon(icon, color: const Color(0xFF8C72FF)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF91A0C3),
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
    this.actionLabel,
  });

  final String title;
  final Widget child;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                if (actionLabel != null)
                  Text(
                    actionLabel!,
                    style: const TextStyle(
                      color: Color(0xFF70A4FF),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _PageHero extends StatelessWidget {
  const _PageHero({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
  });

  final String title;
  final String subtitle;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: const TextStyle(color: Color(0xFF96A2C0)),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF11182A),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF202A43)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.calendar_today_outlined, size: 16),
              const SizedBox(width: 8),
              Text(actionLabel),
            ],
          ),
        ),
      ],
    );
  }
}

class _LoadStatusBreakdown extends StatelessWidget {
  const _LoadStatusBreakdown({required this.loads});

  final List<LoadItem> loads;

  @override
  Widget build(BuildContext context) {
    final statusCounts = <String, int>{
      'In Transit': loads.where((l) => l.status == 'Active').length,
      'Delivered': loads.where((l) => l.status == 'Delivered').length,
      'Pending Paperwork': loads.where((l) => l.paperworkStatus != 'Complete').length,
      'Invoice Ready': loads.where((l) => l.invoiceReady).length,
    };
    final colors = [
      const Color(0xFFF5B94C),
      const Color(0xFF20D3A7),
      const Color(0xFFFF7B7B),
      const Color(0xFF6C4DFF),
    ];

    return Column(
      children: [
        for (var i = 0; i < statusCounts.entries.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: colors[i],
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    statusCounts.entries.elementAt(i).key,
                    style: const TextStyle(color: Color(0xFFB9C5DE)),
                  ),
                ),
                Text('${statusCounts.entries.elementAt(i).value} loads'),
              ],
            ),
          ),
      ],
    );
  }
}

class _RecentLoadsPanel extends StatelessWidget {
  const _RecentLoadsPanel({required this.loads});

  final List<LoadItem> loads;

  @override
  Widget build(BuildContext context) {
    final recent = [...loads]..sort((a, b) => b.createdDate.compareTo(a.createdDate));
    if (recent.isEmpty) {
      return const Text('No loads yet.');
    }

    return Column(
      children: recent.take(4).map((load) {
        final statusColor = switch (load.status) {
          'Delivered' => const Color(0xFF20D3A7),
          'Active' => const Color(0xFFF5B94C),
          _ => const Color(0xFF6C4DFF),
        };
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(load.loadNumber, style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(
                      '${load.pickupLocation} → ${load.deliveryLocation}',
                      style: const TextStyle(color: Color(0xFF92A0C0), fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  load.status,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}


class _RevenueByCompanyChart extends StatelessWidget {
  const _RevenueByCompanyChart({
    required this.loads,
    required this.companies,
  });

  final List<LoadItem> loads;
  final List<Company> companies;

  @override
  Widget build(BuildContext context) {
    final totals = <String, double>{};
    for (final load in loads) {
      totals[load.companyName] = (totals[load.companyName] ?? 0) + load.dispatcherRevenue;
    }
    final entries = totals.entries.toList();
    if (entries.isEmpty) return const Center(child: Text('No chart data'));

    final maxValue = entries.fold<double>(0, (max, entry) => entry.value > max ? entry.value : max);
    return BarChart(
      BarChartData(
        maxY: maxValue == 0 ? 10 : maxValue * 1.2,
        barGroups: [
          for (var i = 0; i < entries.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: entries[i].value,
                  width: 18,
                  color: const Color(0xFFA8E6CF),
                ),
              ],
            ),
        ],
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= entries.length) return const SizedBox();
                final label = entries[index].key;
                return Text(
                  label.length > 8 ? label.substring(0, 8) : label,
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: false),
      ),
    );
  }
}

class _CompanyFeeChart extends StatelessWidget {
  const _CompanyFeeChart({required this.loads});

  final List<LoadItem> loads;

  @override
  Widget build(BuildContext context) {
    final totals = <String, double>{};
    for (final load in loads) {
      totals[load.companyName] = (totals[load.companyName] ?? 0) + load.dispatchFeeAmount;
    }
    final entries = totals.entries.toList();
    if (entries.isEmpty) return const Center(child: Text('No chart data'));

    return _RevenueByCompanyChart(
      loads: [
        for (final entry in entries)
          LoadItem(
            id: entry.key,
            loadNumber: '',
            date: '',
            companyId: '',
            companyName: entry.key,
            dispatcherId: '',
            dispatcherName: '',
            dispatcherEmail: '',
            driverId: '',
            driverName: '',
            truckNumber: '',
            pickupLocation: '',
            deliveryLocation: '',
            routeSummary: '',
            brokerageId: '',
            brokerageName: '',
            brokerageMc: '',
            brokerContact: '',
            loadRate: 0,
            feePercentage: 0,
            dispatchFeeAmount: entry.value,
            dispatcherRevenue: entry.value,
            status: '',
            invoiceStatus: '',
            paymentStatus: '',
            paperworkStatus: '',
            notes: '',
            createdBy: '',
            createdDate: '',
            updatedDate: '',
            rateConfirmationUploaded: false,
            podUploaded: false,
            bolUploaded: false,
            missingDocumentsCount: 0,
          ),
      ],
      companies: const [],
    );
  }
}

class _InvoiceMonthlyChart extends StatelessWidget {
  const _InvoiceMonthlyChart({required this.invoices});

  final List<InvoiceRecord> invoices;

  @override
  Widget build(BuildContext context) {
    final totals = <String, double>{};
    for (final invoice in invoices) {
      final key = invoice.invoiceDate.length >= 7
          ? invoice.invoiceDate.substring(0, 7)
          : invoice.invoiceDate;
      totals[key] = (totals[key] ?? 0) + invoice.invoiceAmount;
    }
    final entries = totals.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    if (entries.isEmpty) return const Center(child: Text('No invoice data'));

    final maxValue = entries.fold<double>(0, (max, entry) => entry.value > max ? entry.value : max);
    return BarChart(
      BarChartData(
        maxY: maxValue == 0 ? 10 : maxValue * 1.2,
        barGroups: [
          for (var i = 0; i < entries.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: entries[i].value,
                  width: 18,
                  color: const Color(0xFFFFD3B6),
                ),
              ],
            ),
        ],
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= entries.length) return const SizedBox();
                return Text(entries[index].key.substring(5));
              },
            ),
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: false),
      ),
    );
  }
}

class _StatusPieChart extends StatelessWidget {
  const _StatusPieChart({required this.loads});

  final List<LoadItem> loads;

  @override
  Widget build(BuildContext context) {
    final delivered = loads.where((load) => load.status == 'Delivered').length.toDouble();
    final active = loads.length.toDouble() - delivered;
    if (loads.isEmpty) return const Center(child: Text('No status data'));

    return PieChart(
      PieChartData(
        sections: [
          PieChartSectionData(
            value: delivered,
            color: const Color(0xFFA8E6CF),
            title: 'Delivered',
          ),
          PieChartSectionData(
            value: active,
            color: const Color(0xFF8EC5FC),
            title: 'Active',
          ),
        ],
      ),
    );
  }
}

class _PaperworkPieChart extends StatelessWidget {
  const _PaperworkPieChart({required this.loads});

  final List<LoadItem> loads;

  @override
  Widget build(BuildContext context) {
    if (loads.isEmpty) return const Center(child: Text('No paperwork data'));

    final complete = loads.where((load) => load.paperworkComplete).length.toDouble();
    final incomplete = loads.length.toDouble() - complete;
    return PieChart(
      PieChartData(
        sections: [
          PieChartSectionData(
            value: complete,
            color: const Color(0xFFA8E6CF),
            title: 'Complete',
          ),
          PieChartSectionData(
            value: incomplete,
            color: const Color(0xFFFFD3B6),
            title: 'Incomplete',
          ),
        ],
      ),
    );
  }
}

class _MonthlyPerformanceLineChart extends StatelessWidget {
  const _MonthlyPerformanceLineChart({required this.loads});

  final List<LoadItem> loads;

  @override
  Widget build(BuildContext context) {
    final grossByMonth = <String, double>{};
    final revenueByMonth = <String, double>{};

    for (final load in loads) {
      final key = load.date.length >= 7 ? load.date.substring(0, 7) : load.date;
      grossByMonth[key] = (grossByMonth[key] ?? 0) + load.loadRate;
      revenueByMonth[key] = (revenueByMonth[key] ?? 0) + load.dispatcherRevenue;
    }

    final keys = {
      ...grossByMonth.keys,
      ...revenueByMonth.keys,
    }.toList()
      ..sort();

    if (keys.isEmpty) return const Center(child: Text('No monthly data'));

    final grossSpots = <FlSpot>[];
    final revenueSpots = <FlSpot>[];
    for (var i = 0; i < keys.length; i++) {
      grossSpots.add(FlSpot(i.toDouble(), grossByMonth[keys[i]] ?? 0));
      revenueSpots.add(FlSpot(i.toDouble(), revenueByMonth[keys[i]] ?? 0));
    }

    final maxY = [
      ...grossSpots.map((s) => s.y),
      ...revenueSpots.map((s) => s.y),
    ].fold<double>(0, (max, value) => value > max ? value : max);

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY == 0 ? 10 : maxY * 1.2,
        gridData: FlGridData(
          show: true,
          getDrawingHorizontalLine: (value) => const FlLine(
            color: Color(0xFF1E2940),
            strokeWidth: 1,
          ),
          getDrawingVerticalLine: (value) => const FlLine(
            color: Color(0x00000000),
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
              getTitlesWidget: (value, meta) => Text(
                '\$${value.toInt()}',
                style: const TextStyle(color: Color(0xFF7685AA), fontSize: 11),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= keys.length) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    keys[index].substring(5),
                    style: const TextStyle(color: Color(0xFF7685AA), fontSize: 11),
                  ),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: grossSpots,
            isCurved: true,
            color: const Color(0xFF7A5BFF),
            barWidth: 3,
            dotData: const FlDotData(show: false),
          ),
          LineChartBarData(
            spots: revenueSpots,
            isCurved: true,
            color: const Color(0xFF19D3C5),
            barWidth: 3,
            dotData: const FlDotData(show: false),
          ),
        ],
      ),
    );
  }
}

class _PaymentStatusDonut extends StatelessWidget {
  const _PaymentStatusDonut({required this.invoices});

  final List<InvoiceRecord> invoices;

  @override
  Widget build(BuildContext context) {
    if (invoices.isEmpty) return const Center(child: Text('No invoice data'));
    final paid = invoices.where((invoice) => invoice.paymentStatus == 'Paid').length.toDouble();
    final unpaid = invoices.length.toDouble() - paid;
    return PieChart(
      PieChartData(
        centerSpaceRadius: 42,
        sectionsSpace: 4,
        sections: [
          PieChartSectionData(
            value: paid,
            color: const Color(0xFF19D3C5),
            title: 'Paid',
            radius: 46,
          ),
          PieChartSectionData(
            value: unpaid,
            color: const Color(0xFF6C4DFF),
            title: 'Pending',
            radius: 46,
          ),
        ],
      ),
    );
  }
}

class _BillingByCompanyChart extends StatelessWidget {
  const _BillingByCompanyChart({required this.invoices});

  final List<InvoiceRecord> invoices;

  @override
  Widget build(BuildContext context) {
    final totals = <String, double>{};
    for (final invoice in invoices) {
      totals[invoice.companyName] = (totals[invoice.companyName] ?? 0) + invoice.invoiceAmount;
    }
    final entries = totals.entries.toList();
    if (entries.isEmpty) return const Center(child: Text('No billing data'));
    final maxY = entries.fold<double>(0, (max, e) => e.value > max ? e.value : max);

    return BarChart(
      BarChartData(
        maxY: maxY == 0 ? 10 : maxY * 1.2,
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: false),
        barGroups: [
          for (var i = 0; i < entries.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: entries[i].value,
                  width: 18,
                  color: const Color(0xFF19D3C5),
                  borderRadius: BorderRadius.circular(6),
                ),
              ],
            ),
        ],
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= entries.length) return const SizedBox();
                final label = entries[index].key;
                return Text(
                  label.length > 7 ? label.substring(0, 7) : label,
                  style: const TextStyle(fontSize: 10, color: Color(0xFF7685AA)),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _MissingDocumentsBar extends StatelessWidget {
  const _MissingDocumentsBar({required this.loads});

  final List<LoadItem> loads;

  @override
  Widget build(BuildContext context) {
    final pod = loads.where((l) => !l.podUploaded).length.toDouble();
    final bol = loads.where((l) => !l.bolUploaded).length.toDouble();
    final rc = loads.where((l) => !l.rateConfirmationUploaded).length.toDouble();
    final entries = [('POD', pod), ('BOL', bol), ('RC', rc)];
    final maxY = entries.fold<double>(0, (max, e) => e.$2 > max ? e.$2 : max);

    return BarChart(
      BarChartData(
        maxY: maxY == 0 ? 10 : maxY * 1.2,
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: false),
        barGroups: [
          for (var i = 0; i < entries.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: entries[i].$2,
                  width: 22,
                  color: const Color(0xFFFF8A65),
                  borderRadius: BorderRadius.circular(6),
                ),
              ],
            ),
        ],
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= entries.length) return const SizedBox();
                return Text(
                  entries[index].$1,
                  style: const TextStyle(fontSize: 10, color: Color(0xFF7685AA)),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _MissingDocsList extends StatelessWidget {
  const _MissingDocsList({required this.loads});

  final List<LoadItem> loads;

  @override
  Widget build(BuildContext context) {
    final flagged = loads.where((load) => load.missingDocumentsCount > 0).take(4).toList();
    if (flagged.isEmpty) return const Text('No missing-document alerts.');
    return Column(
      children: flagged.map((load) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF8A65), size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(load.loadNumber, style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(
                      '${load.missingDocumentsCount} missing docs',
                      style: const TextStyle(color: Color(0xFF92A0C0), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _DispatcherComparisonChart extends StatelessWidget {
  const _DispatcherComparisonChart({required this.loads});

  final List<LoadItem> loads;

  @override
  Widget build(BuildContext context) {
    final totals = <String, double>{};
    for (final load in loads) {
      totals[load.dispatcherName] = (totals[load.dispatcherName] ?? 0) + load.dispatcherRevenue;
    }
    final entries = totals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    if (entries.isEmpty) return const Center(child: Text('No dispatcher data'));
    final maxY = entries.fold<double>(0, (max, e) => e.value > max ? e.value : max);

    return BarChart(
      BarChartData(
        maxY: maxY == 0 ? 10 : maxY * 1.2,
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: false),
        barGroups: [
          for (var i = 0; i < entries.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: entries[i].value,
                  width: 18,
                  color: const Color(0xFF6C4DFF),
                  borderRadius: BorderRadius.circular(6),
                ),
              ],
            ),
        ],
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= entries.length) return const SizedBox();
                final name = entries[index].key;
                return Text(
                  name.length > 8 ? name.substring(0, 8) : name,
                  style: const TextStyle(fontSize: 10, color: Color(0xFF7685AA)),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

String _money(double value) {
  final formatter = NumberFormat.currency(symbol: '\$');
  return formatter.format(value);
}
