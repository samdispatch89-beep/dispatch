// ignore_for_file: unused_element, unused_element_parameter

import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/app_role.dart';
import '../models/app_notification.dart';
import '../models/app_user.dart';
import '../models/activity_log_record.dart';
import '../models/brokerage.dart';
import '../models/company.dart';
import '../models/document_record.dart';
import '../models/driver_record.dart';
import '../models/invoice_record.dart';
import '../models/load_item.dart';
import '../responsive/breakpoints.dart';
import 'invoice_workflow_screen.dart';
import '../services/admin_auth_service.dart';
import '../services/automation_service.dart';
import '../services/error_dialog_service.dart';
import '../services/invoice_service.dart';
import '../services/realtime_service.dart';
import '../services/session_cache_service.dart';
import '../services/storage_service.dart';
import '../shared/widgets/adaptive_data_view.dart';
import '../shared/widgets/responsive_grid.dart';
import '../shared/widgets/responsive_page_container.dart';
import '../theme/app_colors.dart';
import '../theme/theme_controller.dart';

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
  String _searchQuery = '';
  DateTimeRange? _selectedRange;

  List<_NavItem> get _navItems {
    switch (widget.user.role) {
      case AppRole.dispatcher:
        return const [
          _NavItem('Dashboard', Icons.dashboard_outlined),
          _NavItem('Loads', Icons.local_shipping_outlined),
          _NavItem('Add Load', Icons.add_circle_outline),
          _NavItem('Documents', Icons.folder_copy_outlined),
          _NavItem('Reports', Icons.bar_chart_outlined),
          _NavItem('Settings', Icons.settings_outlined),
        ];
      case AppRole.accountant:
        return const [
          _NavItem('Dashboard', Icons.dashboard_outlined),
          _NavItem('Loads', Icons.local_shipping_outlined),
          _NavItem('Invoices', Icons.receipt_long_outlined),
          _NavItem('Documents', Icons.folder_copy_outlined),
          _NavItem('Reports', Icons.bar_chart_outlined),
          _NavItem('Settings', Icons.settings_outlined),
        ];
      case AppRole.paperwork:
        return const [
          _NavItem('Dashboard', Icons.dashboard_outlined),
          _NavItem('Loads', Icons.list_alt_outlined),
          _NavItem('Documents', Icons.folder_copy_outlined),
          _NavItem('Drivers', Icons.person_outline),
          _NavItem('Reports', Icons.bar_chart_outlined),
          _NavItem('Settings', Icons.settings_outlined),
        ];
      case AppRole.admin:
        return const [
          _NavItem('Dashboard', Icons.space_dashboard_outlined),
          _NavItem('Loads', Icons.local_shipping_outlined),
          _NavItem('Add Load', Icons.add_circle_outline),
          _NavItem('Invoices', Icons.receipt_outlined),
          _NavItem('Documents', Icons.folder_copy_outlined),
          _NavItem('Companies', Icons.business_outlined),
          _NavItem('Drivers', Icons.person_outline),
          _NavItem('Brokerages', Icons.apartment_outlined),
          _NavItem('Reports', Icons.bar_chart_outlined),
          _NavItem('Settings', Icons.settings_outlined),
        ];
    }
  }

  Future<void> _signOut() async {
    await SessionCacheService.instance.clear();
    await FirebaseAuth.instance.signOut();
  }

  Future<void> _openThemeSettings() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => const _ThemeSettingsSheet(),
    );
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
                    final filteredLoads =
                        loads.where(_loadMatchesFilters).toList();
                    final filteredInvoices =
                        invoices.where(_invoiceMatchesFilters).toList();
                    final currentPage = _buildCurrentPage(
                      context,
                      loads: filteredLoads,
                      companies: companies,
                      brokerages: brokerages,
                      invoices: filteredInvoices,
                    );

                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final colors = context.dashboardColors;
                        final desktop = constraints.maxWidth >= 1100;
                        final tablet = constraints.maxWidth >= 760;
                        final wideRail = constraints.maxWidth >= 1280;

                        if (desktop) {
                          return Scaffold(
                            body: SafeArea(
                              child: ResponsivePageContainer(
                                padding: EdgeInsets.all(
                                  AppBreakpoints.pagePadding(context),
                                ),
                                child: Row(
                                  children: [
                                    _DrawerRail(
                                      items: _navItems,
                                      currentIndex: _currentIndex,
                                      onSelected: (index) {
                                        setState(() => _currentIndex = index);
                                      },
                                      onSignOut: _signOut,
                                      expanded: wideRail,
                                    ),
                                    const SizedBox(width: 18),
                                    Expanded(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: colors.panel,
                                          borderRadius: BorderRadius.circular(
                                            28,
                                          ),
                                          border: Border.all(
                                            color: colors.border,
                                          ),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                            18,
                                            18,
                                            18,
                                            18,
                                          ),
                                          child: Column(
                                            children: [
                                              _TopToolbar(
                                                user: widget.user,
                                                title:
                                                    _navItems[_currentIndex]
                                                        .label,
                                                onOpenThemeSettings:
                                                    _openThemeSettings,
                                                searchQuery: _searchQuery,
                                                selectedRange: _selectedRange,
                                                onSearchChanged: (value) {
                                                  setState(
                                                    () => _searchQuery = value,
                                                  );
                                                },
                                                onDateRangeChanged: (range) {
                                                  setState(
                                                    () => _selectedRange = range,
                                                  );
                                                },
                                              ),
                                              const SizedBox(height: 18),
                                              Expanded(child: currentPage),
                                            ],
                                          ),
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
                              child: _DrawerMenu(
                                items: _navItems,
                                currentIndex: _currentIndex,
                                onSelected: (index) {
                                  setState(() => _currentIndex = index);
                                  Navigator.of(context).pop();
                                },
                                onSignOut: _signOut,
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
                                  onOpenThemeSettings: _openThemeSettings,
                                  searchQuery: _searchQuery,
                                  selectedRange: _selectedRange,
                                  onSearchChanged: (value) {
                                    setState(() => _searchQuery = value);
                                  },
                                  onDateRangeChanged: (range) {
                                    setState(() => _selectedRange = range);
                                  },
                                  compact: true,
                                ),
                                const SizedBox(height: 14),
                                Expanded(child: currentPage),
                              ],
                            ),
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
    final route = _navItems[_currentIndex].label;
    switch (route) {
      case 'Dashboard':
        return _ModernDashboard(
          user: widget.user,
          loads: loads,
          invoices: invoices,
          onNavigate: (label) {
            final index = _navItems.indexWhere((item) => item.label == label);
            if (index >= 0) {
              setState(() => _currentIndex = index);
            }
          },
        );
      case 'Loads':
        return _LoadsListPage(
          user: widget.user,
          loads: loads,
          companies: companies,
          brokerages: brokerages,
          onOpen: _openLoadDetails,
          onEdit: _editLoad,
          onDelete: _deleteLoad,
        );
      case 'Add Load':
        return _LoadCreatePage(
          user: widget.user,
          companies: companies,
          brokerages: brokerages,
          onCreated: _showMessage,
        );
      case 'Invoices':
        return _InvoicesPage(
          user: widget.user,
          companies: companies,
          loads: loads,
          invoices: invoices,
          onMessage: _showMessage,
          onMarkSent: _markInvoiceSent,
          onMarkPaid: _markInvoicePaid,
          onDownloadPdf: _downloadInvoicePdf,
        );
      case 'Documents':
        return _DocumentsPage(
          user: widget.user,
          onMessage: _showMessage,
          onDeleteDocument: _deleteDocument,
        );
      case 'Companies':
        return _CompaniesPage(
          companies: companies,
          onMessage: _showMessage,
          onDelete: _deleteCompany,
        );
      case 'Drivers':
        return _DriversPage(onMessage: _showMessage, onDelete: _deleteDriver);
      case 'Brokerages':
        return _BrokeragesPage(
          brokerages: brokerages,
          onMessage: _showMessage,
          onDelete: _deleteBrokerage,
        );
      case 'Reports':
        return _ReportsPage(
          user: widget.user,
          loads: loads,
          invoices: invoices,
          companies: companies,
        );
      case 'Settings':
        return _SettingsPage(
          user: widget.user,
          onOpenThemeSettings: _openThemeSettings,
          onMessage: _showMessage,
        );
      default:
        return const SizedBox.shrink();
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

  Future<void> _editLoad(
    LoadItem load, {
    required List<Company> companies,
    required List<Brokerage> brokerages,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _LoadFormDialog(
        user: widget.user,
        companies: companies,
        brokerages: brokerages,
        initialLoad: load,
        onMessage: _showMessage,
      ),
    );
  }

  Future<void> _deleteLoad(LoadItem load) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Load'),
        content: Text(
          'Delete ${load.loadNumber}? This cannot be undone for non-invoiced loads.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _realtime.deleteLoad(load.id);
      _showMessage('${load.loadNumber} deleted.');
    } catch (error) {
      _showMessage(error.toString());
    }
  }

  Future<void> _deleteCompany(Company company) async {
    final confirmed = await _confirmDelete('Delete ${company.name}?');
    if (!confirmed) return;
    try {
      await _realtime.deleteCompany(company.id);
      _showMessage('${company.name} deleted.');
    } catch (error) {
      _showMessage(error.toString());
    }
  }

  Future<void> _deleteBrokerage(Brokerage brokerage) async {
    final confirmed = await _confirmDelete('Delete ${brokerage.name}?');
    if (!confirmed) return;
    try {
      await _realtime.deleteBrokerage(brokerage.id);
      _showMessage('${brokerage.name} deleted.');
    } catch (error) {
      _showMessage(error.toString());
    }
  }

  Future<void> _deleteDriver(DriverRecord driver) async {
    final confirmed = await _confirmDelete('Delete ${driver.name}?');
    if (!confirmed) return;
    try {
      await _realtime.deleteDriver(driver.id);
      _showMessage('${driver.name} deleted.');
    } catch (error) {
      _showMessage(error.toString());
    }
  }

  Future<void> _deleteDocument(DocumentRecord document) async {
    final confirmed = await _confirmDelete('Delete ${document.fileName}?');
    if (!confirmed) return;
    try {
      if (document.storagePath.isNotEmpty) {
        await _storageService.deleteByPath(document.storagePath);
      }
      await _realtime.deleteDocument(document.id);
      _showMessage('${document.fileName} deleted.');
    } catch (error) {
      _showMessage(error.toString());
    }
  }

  Future<bool> _confirmDelete(String message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _markInvoicePaid(InvoiceRecord invoice) async {
    await _realtime.setInvoicePaid(invoice);
    _showMessage('${invoice.invoiceNumber} marked paid');
  }

  Future<void> _markInvoiceSent(InvoiceRecord invoice) async {
    await _realtime.setInvoiceSent(invoice);
    _showMessage('${invoice.invoiceNumber} marked sent');
  }

  Future<void> _downloadInvoicePdf(InvoiceRecord invoice) async {
    final url = invoice.invoiceFileUrl.trim();
    if (url.isEmpty) {
      _showMessage('No PDF is available for invoice ${invoice.invoiceNumber}.');
      return;
    }

    final uri = Uri.tryParse(url);
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _showMessage(
        'Unable to open the PDF download for ${invoice.invoiceNumber}.',
      );
    }
  }

  bool _loadMatchesFilters(LoadItem load) {
    final query = _searchQuery.trim().toLowerCase();
    final inSearch = query.isEmpty ||
        [
          load.loadNumber,
          load.companyName,
          load.driverName,
          load.dispatcherName,
          load.brokerageName,
          load.brokerageMc,
          load.yearWeek,
          load.operationalStatus,
          load.financialStatus,
        ].any((value) => value.toLowerCase().contains(query));

    if (!inSearch) return false;
    if (_selectedRange == null) return true;
    final parsed = DateTime.tryParse(load.date);
    if (parsed == null) return false;
    final day = DateTime(parsed.year, parsed.month, parsed.day);
    final start = DateTime(
      _selectedRange!.start.year,
      _selectedRange!.start.month,
      _selectedRange!.start.day,
    );
    final end = DateTime(
      _selectedRange!.end.year,
      _selectedRange!.end.month,
      _selectedRange!.end.day,
    );
    return !day.isBefore(start) && !day.isAfter(end);
  }

  bool _invoiceMatchesFilters(InvoiceRecord invoice) {
    final query = _searchQuery.trim().toLowerCase();
    final inSearch = query.isEmpty ||
        [
          invoice.invoiceNumber,
          invoice.companyName,
          invoice.yearWeek,
          invoice.invoiceStatus,
          invoice.paymentStatus,
        ].any((value) => value.toLowerCase().contains(query));
    if (!inSearch) return false;
    if (_selectedRange == null) return true;
    final parsed = DateTime.tryParse(invoice.invoiceDate);
    if (parsed == null) return false;
    final day = DateTime(parsed.year, parsed.month, parsed.day);
    final start = DateTime(
      _selectedRange!.start.year,
      _selectedRange!.start.month,
      _selectedRange!.start.day,
    );
    final end = DateTime(
      _selectedRange!.end.year,
      _selectedRange!.end.month,
      _selectedRange!.end.day,
    );
    return !day.isBefore(start) && !day.isAfter(end);
  }

  void _showMessage(String message) {
    if (!mounted) return;
    final lowered = message.toLowerCase();
    final isError =
        lowered.contains('failed') ||
        lowered.contains('error') ||
        lowered.contains('unable') ||
        lowered.contains('cannot');
    if (isError) {
      ErrorDialogService.show(context, message: message);
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
          onGenerateInvoice: widget.user.isAccountant || widget.user.isAdmin
              ? _generateInvoice
              : null,
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
    final colors = context.dashboardColors;
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
        gradient: LinearGradient(
          colors: [colors.panel, colors.surfaceAlt],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: Border.all(color: colors.border),
      ),
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_shipping, color: colors.primary),
              const SizedBox(width: 10),
              Text(
                'DISPATCH FLOW',
                style: TextStyle(
                  color: colors.primary,
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
          Text(
            'Smarter dispatch operations with live visibility, cleaner paperwork flow, and sharper revenue insights.',
            style: TextStyle(color: colors.muted, height: 1.5),
          ),
          const SizedBox(height: 28),
          Text(
            'KEY FEATURES',
            style: TextStyle(
              color: colors.muted,
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
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.check_circle_outline,
                      size: 18,
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      feature,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
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
              gradient: LinearGradient(
                colors: [
                  colors.primary.withValues(alpha: 0.18),
                  colors.surfaceAlt,
                ],
              ),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Realtime. Role-aware. Revenue-driven.',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  'A single command center for dispatch, paperwork, accounting, and admin.',
                  style: TextStyle(color: colors.muted, height: 1.5),
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
    required this.onOpenThemeSettings,
    this.compact = false,
  });

  final List<_NavItem> items;
  final int currentIndex;
  final ValueChanged<int> onSelected;
  final AppUser user;
  final Future<void> Function() onSignOut;
  final Future<void> Function() onOpenThemeSettings;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.dashboardColors;
    return Container(
      width: compact ? double.infinity : 220,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: compact ? Colors.transparent : colors.surfaceAlt,
        borderRadius: compact
            ? null
            : const BorderRadius.only(
                topLeft: Radius.circular(28),
                bottomLeft: Radius.circular(28),
              ),
        border: compact
            ? null
            : Border(right: BorderSide(color: colors.border)),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: selected ? colors.primary : const Color(0x00000000),
                    border: Border.all(
                      color: selected ? colors.primary : colors.border,
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
              color: colors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.border),
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
                        style: TextStyle(color: colors.muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Theme',
                  onPressed: onOpenThemeSettings,
                  icon: const Icon(Icons.palette_outlined, size: 18),
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
    required this.onOpenThemeSettings,
    required this.searchQuery,
    required this.selectedRange,
    required this.onSearchChanged,
    required this.onDateRangeChanged,
    this.compact = false,
  });

  final AppUser user;
  final String title;
  final Future<void> Function() onOpenThemeSettings;
  final String searchQuery;
  final DateTimeRange? selectedRange;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<DateTimeRange?> onDateRangeChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.dashboardColors;
    final formatter = DateFormat('MMM d');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: colors.surfaceAlt,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          if (!compact) ...[
            Expanded(
              child: Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 16),
          ],
          Expanded(
            flex: compact ? 1 : 2,
            child: TextField(
              controller: TextEditingController(text: searchQuery)
                ..selection = TextSelection.collapsed(
                  offset: searchQuery.length,
                ),
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                hintText: compact
                    ? 'Search loads...'
                    : 'Search loads, drivers, brokerages...',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                filled: true,
                fillColor: colors.panel,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: colors.border),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          OutlinedButton.icon(
            onPressed: () async {
              final now = DateTime.now();
              final range = await showDateRangePicker(
                context: context,
                firstDate: DateTime(now.year - 2),
                lastDate: DateTime(now.year + 2),
                initialDateRange: selectedRange,
              );
              onDateRangeChanged(range);
            },
            icon: const Icon(Icons.calendar_today_outlined, size: 16),
            label: Text(
              selectedRange == null
                  ? 'Date Range'
                  : '${formatter.format(selectedRange!.start)} - ${formatter.format(selectedRange!.end)}',
            ),
          ),
          const SizedBox(width: 8),
          if (!compact) ...[
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.notifications_none),
            ),
            IconButton(onPressed: () {}, icon: const Icon(Icons.help_outline)),
            IconButton(
              onPressed: onOpenThemeSettings,
              icon: const Icon(Icons.palette_outlined),
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
                  style: TextStyle(color: colors.muted, fontSize: 12),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DrawerMenu extends StatelessWidget {
  const _DrawerMenu({
    required this.items,
    required this.currentIndex,
    required this.onSelected,
    required this.onSignOut,
  });

  final List<_NavItem> items;
  final int currentIndex;
  final ValueChanged<int> onSelected;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    final colors = context.dashboardColors;
    return Container(
      color: colors.surface,
      child: Column(
        children: [
          DrawerHeader(
            margin: EdgeInsets.zero,
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Text(
                'Dispatch Flow',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final selected = index == currentIndex;
                return ListTile(
                  selected: selected,
                  leading: Icon(item.icon),
                  title: Text(item.label),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  onTap: () => onSelected(index),
                );
              },
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout_outlined),
            title: const Text('Logout'),
            onTap: onSignOut,
          ),
        ],
      ),
    );
  }
}

class _DrawerRail extends StatelessWidget {
  const _DrawerRail({
    required this.items,
    required this.currentIndex,
    required this.onSelected,
    required this.onSignOut,
    required this.expanded,
  });

  final List<_NavItem> items;
  final int currentIndex;
  final ValueChanged<int> onSelected;
  final Future<void> Function() onSignOut;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final colors = context.dashboardColors;
    return Container(
      width: expanded ? 220 : 88,
      decoration: BoxDecoration(
        color: colors.surfaceAlt,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          const SizedBox(height: 18),
          Icon(Icons.local_shipping_outlined, color: colors.primary),
          const SizedBox(height: 8),
          if (expanded)
            Text(
              'Dispatch Flow',
              style: TextStyle(
                color: colors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          const SizedBox(height: 16),
          Expanded(
            child: NavigationRail(
              extended: expanded,
              backgroundColor: Colors.transparent,
              minExtendedWidth: 220,
              selectedIndex: currentIndex,
              useIndicator: true,
              onDestinationSelected: onSelected,
              destinations: items
                  .map(
                    (item) => NavigationRailDestination(
                      icon: Icon(item.icon),
                      label: Text(item.label),
                    ),
                  )
                  .toList(),
            ),
          ),
          IconButton(
            onPressed: onSignOut,
            icon: const Icon(Icons.logout_outlined),
            tooltip: 'Logout',
          ),
          const SizedBox(height: 12),
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
    final colors = context.dashboardColors;
    final name = user.name.trim().isEmpty ? user.email : user.name;
    final parts = name.split(' ').where((part) => part.isNotEmpty).toList();
    final initials = parts.isEmpty
        ? 'U'
        : parts.take(2).map((part) => part[0].toUpperCase()).join();

    return Container(
      width: 40,
      height: 40,
      decoration: const BoxDecoration(shape: BoxShape.circle),
      alignment: Alignment.center,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(colors: [colors.primary, colors.secondary]),
        ),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Center(
            child: Text(
              initials,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ThemeSettingsSheet extends StatelessWidget {
  const _ThemeSettingsSheet();

  @override
  Widget build(BuildContext context) {
    final colors = context.dashboardColors;
    return Consumer<ThemeController>(
      builder: (context, controller, _) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Appearance',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose how Dispatch Flow looks across mobile, tablet, and desktop.',
                  style: TextStyle(color: colors.muted),
                ),
                const SizedBox(height: 16),
                RadioGroup<ThemePreference>(
                  groupValue: controller.preference,
                  onChanged: (value) {
                    if (value != null) {
                      controller.update(value);
                    }
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: ThemePreference.values
                        .map(
                          (preference) => RadioListTile<ThemePreference>(
                            value: preference,
                            title: Text(switch (preference) {
                              ThemePreference.system => 'System',
                              ThemePreference.light => 'Light',
                              ThemePreference.dark => 'Dark',
                            }),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
    final totalRevenue = loads.fold<double>(
      0,
      (sum, load) => sum + load.dispatcherRevenue,
    );
    final weekParts = RealtimeService.instance.isoWeekParts(DateTime.now());
    final weekLoads = loads
        .where((load) => load.yearWeek == weekParts.yearWeek)
        .toList();
    final weeklyGross = weekLoads.fold<double>(
      0,
      (sum, load) => sum + load.loadRate,
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _PageHero(
          title: 'Welcome back, ${user.name.split(' ').first}',
          subtitle:
              'Here is what is happening with your dispatch operation today.',
          actionLabel: 'This Month',
        ),
        const SizedBox(height: 18),
        ResponsiveGrid(
          children: [
            _SummaryCard(
              title: 'My Loads',
              value: '${loads.length}',
              icon: Icons.local_shipping_outlined,
            ),
            _SummaryCard(
              title: 'Delivered',
              value: '$delivered',
              icon: Icons.check_circle_outline,
            ),
            _SummaryCard(
              title: 'Active',
              value: '$active',
              icon: Icons.timelapse_outlined,
            ),
            _SummaryCard(
              title: 'Revenue',
              value: _money(totalRevenue),
              icon: Icons.attach_money_outlined,
            ),
            _SummaryCard(
              title: 'Weekly Gross',
              value: _money(weeklyGross),
              icon: Icons.bar_chart_outlined,
            ),
          ],
        ),
        const SizedBox(height: 20),
        _SectionCard(
          title: 'Dispatcher Alerts',
          child: _DispatcherNotifications(userId: user.uid),
        ),
        const SizedBox(height: 16),
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
                      child: _RevenueByCompanyChart(
                        loads: loads,
                        companies: companies,
                      ),
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
                      child: _RevenueByCompanyChart(
                        loads: loads,
                        companies: companies,
                      ),
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
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Weekly Driver Earnings',
          child: SizedBox(
            height: 260,
            child: _WeeklyDriverEarningsChart(loads: weekLoads),
          ),
        ),
      ],
    );
  }
}

class _DispatcherEarningsPage extends StatelessWidget {
  const _DispatcherEarningsPage({required this.loads, required this.companies});

  final List<LoadItem> loads;
  final List<Company> companies;

  @override
  Widget build(BuildContext context) {
    final total = loads.fold<double>(
      0,
      (sum, load) => sum + load.dispatcherRevenue,
    );
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final daily = loads
        .where((load) => load.date == today)
        .fold<double>(0, (sum, load) => sum + load.dispatcherRevenue);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _PageHero(
          title: 'Accounting Dashboard',
          subtitle:
              'Monitor invoicing, receivables, and company billing performance.',
          actionLabel: 'This Month',
        ),
        const SizedBox(height: 18),
        ResponsiveGrid(
          children: [
            _SummaryCard(
              title: 'Today',
              value: _money(daily),
              icon: Icons.today_outlined,
            ),
            _SummaryCard(
              title: 'Total',
              value: _money(total),
              icon: Icons.paid_outlined,
            ),
            _SummaryCard(
              title: 'Delivered Loads',
              value:
                  '${loads.where((load) => load.status == 'Delivered').length}',
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
  const _AccountantDashboard({required this.loads, required this.invoices});

  final List<LoadItem> loads;
  final List<InvoiceRecord> invoices;

  @override
  Widget build(BuildContext context) {
    final generated = invoices.length;
    final unpaid = invoices
        .where((invoice) => invoice.paymentStatus != 'Paid')
        .length;
    final receivables = invoices
        .where((invoice) => invoice.paymentStatus != 'Paid')
        .fold<double>(0, (sum, invoice) => sum + invoice.invoiceAmount);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ResponsiveGrid(
          children: [
            _SummaryCard(
              title: 'Invoices',
              value: '$generated',
              icon: Icons.receipt_long_outlined,
            ),
            _SummaryCard(
              title: 'Unpaid',
              value: '$unpaid',
              icon: Icons.warning_amber_outlined,
            ),
            _SummaryCard(
              title: 'Receivables',
              value: _money(receivables),
              icon: Icons.account_balance_outlined,
            ),
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
          child: SizedBox(
            height: 240,
            child: _InvoiceMonthlyChart(invoices: invoices),
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 840) {
              return Column(
                children: [
                  _SectionCard(
                    title: 'Paid vs Unpaid',
                    child: SizedBox(
                      height: 220,
                      child: _PaymentStatusDonut(invoices: invoices),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SectionCard(
                    title: 'Billing by Company',
                    child: SizedBox(
                      height: 220,
                      child: _BillingByCompanyChart(invoices: invoices),
                    ),
                  ),
                ],
              );
            }
            return Row(
              children: [
                Expanded(
                  child: _SectionCard(
                    title: 'Paid vs Unpaid',
                    child: SizedBox(
                      height: 220,
                      child: _PaymentStatusDonut(invoices: invoices),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _SectionCard(
                    title: 'Billing by Company',
                    child: SizedBox(
                      height: 220,
                      child: _BillingByCompanyChart(invoices: invoices),
                    ),
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
    final missingRc = loads
        .where((load) => !load.rateConfirmationUploaded)
        .length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _PageHero(
          title: 'Paperwork Dashboard',
          subtitle:
              'Track upload completeness and clear missing-document alerts faster.',
          actionLabel: 'Operational View',
        ),
        const SizedBox(height: 18),
        ResponsiveGrid(
          children: [
            _SummaryCard(
              title: 'Missing PODs',
              value: '$missingPod',
              icon: Icons.description_outlined,
            ),
            _SummaryCard(
              title: 'Missing BOLs',
              value: '$missingBol',
              icon: Icons.assignment_late_outlined,
            ),
            _SummaryCard(
              title: 'Missing RCs',
              value: '$missingRc',
              icon: Icons.error_outline,
            ),
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
                    child: SizedBox(
                      height: 220,
                      child: _MissingDocumentsBar(loads: loads),
                    ),
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
                    child: SizedBox(
                      height: 220,
                      child: _MissingDocumentsBar(loads: loads),
                    ),
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
  const _AdminDashboard({required this.loads, required this.invoices});

  final List<LoadItem> loads;
  final List<InvoiceRecord> invoices;

  @override
  Widget build(BuildContext context) {
    final gross = loads.fold<double>(0, (sum, load) => sum + load.loadRate);
    final fees = loads.fold<double>(
      0,
      (sum, load) => sum + load.dispatchFeeAmount,
    );
    final unpaid = invoices
        .where((invoice) => invoice.paymentStatus != 'Paid')
        .fold<double>(0, (sum, invoice) => sum + invoice.invoiceAmount);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _PageHero(
          title: 'Admin Dashboard',
          subtitle:
              'Monitor revenue, dispatcher performance, paperwork health, and outstanding payments.',
          actionLabel: 'This Month',
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _SummaryCard(
              title: 'Total Loads',
              value: '${loads.length}',
              icon: Icons.list_alt_outlined,
            ),
            _SummaryCard(
              title: 'Gross Volume',
              value: _money(gross),
              icon: Icons.bar_chart_outlined,
            ),
            _SummaryCard(
              title: 'Dispatch Fees',
              value: _money(fees),
              icon: Icons.attach_money_outlined,
            ),
            _SummaryCard(
              title: 'Outstanding',
              value: _money(unpaid),
              icon: Icons.pending_outlined,
            ),
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
                    child: SizedBox(
                      height: 240,
                      child: _DispatcherComparisonChart(loads: loads),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SectionCard(
                    title: 'Paperwork Status',
                    child: SizedBox(
                      height: 240,
                      child: _PaperworkPieChart(loads: loads),
                    ),
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
                    child: SizedBox(
                      height: 240,
                      child: _DispatcherComparisonChart(loads: loads),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 3,
                  child: _SectionCard(
                    title: 'Paperwork Status',
                    child: SizedBox(
                      height: 240,
                      child: _PaperworkPieChart(loads: loads),
                    ),
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
    required this.companies,
    required this.brokerages,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
    this.emptyLabel = 'No loads available.',
  });

  final AppUser user;
  final List<LoadItem> loads;
  final List<Company> companies;
  final List<Brokerage> brokerages;
  final Future<void> Function(LoadItem load) onOpen;
  final Future<void> Function(
    LoadItem load, {
    required List<Company> companies,
    required List<Brokerage> brokerages,
  })
  onEdit;
  final Future<void> Function(LoadItem load) onDelete;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    if (loads.isEmpty) {
      return Center(child: Text(emptyLabel));
    }

    return ResponsivePageContainer(
      child: AdaptiveDataView(
        itemCount: loads.length,
        empty: Center(child: Text(emptyLabel)),
        cardBuilder: (context, index) {
          final load = loads[index];
          return Card(
            child: ListTile(
              title: Text('${load.loadNumber} • ${load.routeSummary}'),
              subtitle: Text(
                '${load.companyName} • ${load.driverName} • ${load.status}\n'
                'Fee: ${_money(load.dispatchFeeAmount)} • Invoice: ${load.invoiceStatus} • Paperwork: ${load.paperworkStatus}',
              ),
              isThreeLine: true,
              trailing: PopupMenuButton<String>(
                onSelected: (value) async {
                  switch (value) {
                    case 'view':
                      await onOpen(load);
                      break;
                    case 'edit':
                      await onEdit(
                        load,
                        companies: companies,
                        brokerages: brokerages,
                      );
                      break;
                    case 'delete':
                      await onDelete(load);
                      break;
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'view', child: Text('View Details')),
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
              onTap: () => onOpen(load),
            ),
          );
        },
        tableBuilder: (context) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Load #')),
              DataColumn(label: Text('Route')),
              DataColumn(label: Text('Company')),
              DataColumn(label: Text('Driver')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Fee')),
              DataColumn(label: Text('Actions')),
            ],
            rows: loads
                .map(
                  (load) => DataRow(
                    cells: [
                      DataCell(Text(load.loadNumber)),
                      DataCell(Text(load.routeSummary)),
                      DataCell(Text(load.companyName)),
                      DataCell(Text(load.driverName)),
                      DataCell(Text(load.operationalStatus)),
                      DataCell(Text(_money(load.dispatchFeeAmount))),
                      DataCell(
                        Wrap(
                          spacing: 8,
                          children: [
                            IconButton(
                              tooltip: 'View',
                              onPressed: () => onOpen(load),
                              icon: const Icon(Icons.visibility_outlined),
                            ),
                            IconButton(
                              tooltip: 'Edit',
                              onPressed: () => onEdit(
                                load,
                                companies: companies,
                                brokerages: brokerages,
                              ),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            IconButton(
                              tooltip: 'Delete',
                              onPressed: () => onDelete(load),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
                .toList(),
          ),
        ),
      ),
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
      final exists = await RealtimeService.instance.loadNumberExists(
        _loadNumber.text.trim(),
      );
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
      final weekParts = RealtimeService.instance.isoWeekParts(DateTime.now());
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
        operationalStatus: 'New',
        financialStatus: 'Not Invoiced',
        invoiceStatus: 'Not Invoiced',
        paymentStatus: 'Unpaid',
        paperworkStatus: 'Incomplete',
        notes: _notes.text.trim(),
        createdBy: widget.user.uid,
        createdDate: now,
        updatedDate: now,
        year: weekParts.year,
        week: weekParts.week,
        yearWeek: weekParts.yearWeek,
        deliveryDateTime: '',
        rateConfirmationUploaded: false,
        podUploaded: false,
        podUploadedAt: '',
        podDelayFlag: false,
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
    Company? resolvedCompany;
    if (_company != null) {
      for (final company in widget.companies) {
        if (company.id == _company!.id) {
          resolvedCompany = company;
          break;
        }
      }
    }
    Brokerage? resolvedBrokerage;
    if (_brokerage != null) {
      for (final brokerage in widget.brokerages) {
        if (brokerage.id == _brokerage!.id) {
          resolvedBrokerage = brokerage;
          break;
        }
      }
    }
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
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Required'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<Company>(
                    initialValue: resolvedCompany,
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
                    initialValue: resolvedBrokerage,
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
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Required'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _driverPhone,
                    decoration: const InputDecoration(
                      labelText: 'Driver Phone',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _truckNumber,
                    decoration: const InputDecoration(
                      labelText: 'Truck Number',
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Required'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _pickup,
                    decoration: const InputDecoration(
                      labelText: 'Pickup Location',
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Required'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _delivery,
                    decoration: const InputDecoration(
                      labelText: 'Delivery Location',
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Required'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _brokerContact,
                    decoration: const InputDecoration(
                      labelText: 'Broker Contact',
                    ),
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
                        (double.tryParse(value ?? '') ?? 0) <= 0
                        ? 'Enter a valid amount'
                        : null,
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

class _InvoicesPage extends StatelessWidget {
  const _InvoicesPage({
    required this.user,
    required this.companies,
    required this.loads,
    required this.invoices,
    required this.onMessage,
    required this.onMarkSent,
    required this.onMarkPaid,
    required this.onDownloadPdf,
  });

  final AppUser user;
  final List<Company> companies;
  final List<LoadItem> loads;
  final List<InvoiceRecord> invoices;
  final void Function(String message) onMessage;
  final Future<void> Function(InvoiceRecord invoice) onMarkSent;
  final Future<void> Function(InvoiceRecord invoice) onMarkPaid;
  final Future<void> Function(InvoiceRecord invoice) onDownloadPdf;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'Generator'),
              Tab(text: 'Status'),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TabBarView(
              children: [
                InvoiceWorkflowScreen(
                  user: user,
                  companies: companies,
                  loads: loads,
                  invoices: invoices,
                  onMessage: onMessage,
                  onMarkSent: onMarkSent,
                  onMarkPaid: onMarkPaid,
                ),
                _PaymentsPage(
                  invoices: invoices,
                  onMarkPaid: onMarkPaid,
                  onDownloadPdf: onDownloadPdf,
                  onMarkSent: onMarkSent,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentsPage extends StatelessWidget {
  const _PaymentsPage({
    required this.invoices,
    required this.onMarkPaid,
    required this.onDownloadPdf,
    this.onMarkSent,
  });

  final List<InvoiceRecord> invoices;
  final Future<void> Function(InvoiceRecord invoice) onMarkPaid;
  final Future<void> Function(InvoiceRecord invoice) onDownloadPdf;
  final Future<void> Function(InvoiceRecord invoice)? onMarkSent;

  @override
  Widget build(BuildContext context) {
    if (invoices.isEmpty) {
      return const Center(child: Text('No invoices yet.'));
    }

    return ResponsivePageContainer(
      child: AdaptiveDataView(
        itemCount: invoices.length,
        cardBuilder: (context, index) {
          final invoice = invoices[index];
          return Card(
            child: ListTile(
              title: Text('${invoice.invoiceNumber} • ${invoice.companyName}'),
              subtitle: Text(
                'Amount: ${_money(invoice.invoiceAmount)} • Status: ${invoice.paymentStatus}\nDue: ${invoice.dueDate}',
              ),
              isThreeLine: true,
              trailing: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => onDownloadPdf(invoice),
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('PDF'),
                  ),
                  if (invoice.invoiceStatus != 'Invoice Sent' &&
                      onMarkSent != null)
                    OutlinedButton(
                      onPressed: () => onMarkSent!(invoice),
                      child: const Text('Mark Sent'),
                    ),
                  if (invoice.paymentStatus == 'Paid')
                    const Chip(label: Text('Paid'))
                  else
                    ElevatedButton(
                      onPressed: () => onMarkPaid(invoice),
                      child: const Text('Mark Paid'),
                    ),
                ],
              ),
            ),
          );
        },
        tableBuilder: (context) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Invoice #')),
              DataColumn(label: Text('Company')),
              DataColumn(label: Text('Loads')),
              DataColumn(label: Text('Amount')),
              DataColumn(label: Text('Due')),
              DataColumn(label: Text('PDF')),
              DataColumn(label: Text('Sent')),
              DataColumn(label: Text('Payment')),
            ],
            rows: invoices
                .map(
                  (invoice) => DataRow(
                    cells: [
                      DataCell(Text(invoice.invoiceNumber)),
                      DataCell(Text(invoice.companyName)),
                      DataCell(Text('${invoice.totalLoads}')),
                      DataCell(Text(_money(invoice.invoiceAmount))),
                      DataCell(Text(invoice.dueDate)),
                      DataCell(
                        OutlinedButton.icon(
                          onPressed: () => onDownloadPdf(invoice),
                          icon: const Icon(Icons.download_outlined),
                          label: const Text('Download'),
                        ),
                      ),
                      DataCell(
                        invoice.invoiceStatus == 'Invoice Sent' || onMarkSent == null
                            ? const Chip(label: Text('Sent'))
                            : OutlinedButton(
                                onPressed: () => onMarkSent!(invoice),
                                child: const Text('Mark Sent'),
                              ),
                      ),
                      DataCell(
                        invoice.paymentStatus == 'Paid'
                            ? const Chip(label: Text('Paid'))
                            : ElevatedButton(
                                onPressed: () => onMarkPaid(invoice),
                                child: const Text('Mark Paid'),
                              ),
                      ),
                    ],
                  ),
                )
                .toList(),
          ),
        ),
      ),
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
    required this.onDelete,
  });

  final List<Company> companies;
  final void Function(String message) onMessage;
  final Future<void> Function(Company company) onDelete;

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
        if (companies.isEmpty)
          const _EmptyStateCard(
            title: 'No companies found',
            subtitle: 'Add a company to manage dispatch fee configuration.',
          ),
        ...companies.map(
          (company) => Card(
            child: ListTile(
              title: Text(company.name),
              subtitle: Text(
                'Fee: ${company.feePercentage.toStringAsFixed(2)}% • Billing: ${company.billingEmail}',
              ),
              trailing: PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'edit') {
                    await showDialog<void>(
                      context: context,
                      builder: (context) => _CompanyFormDialog(
                        onMessage: onMessage,
                        initialCompany: company,
                      ),
                    );
                  } else if (value == 'delete') {
                    await onDelete(company);
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
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
    required this.onDelete,
  });

  final List<Brokerage> brokerages;
  final void Function(String message) onMessage;
  final Future<void> Function(Brokerage brokerage) onDelete;

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
                builder: (context) =>
                    _BrokerageFormDialog(onMessage: onMessage),
              );
            },
            icon: const Icon(Icons.add_business_outlined),
            label: const Text('Add brokerage'),
          ),
        ),
        const SizedBox(height: 12),
        if (brokerages.isEmpty)
          const _EmptyStateCard(
            title: 'No brokerages found',
            subtitle: 'Add a brokerage to connect future loads.',
          ),
        ...brokerages.map(
          (brokerage) => Card(
            child: ListTile(
              title: Text(brokerage.name),
              subtitle: Text('MC: ${brokerage.mc}'),
              trailing: PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'edit') {
                    await showDialog<void>(
                      context: context,
                      builder: (context) => _BrokerageFormDialog(
                        onMessage: onMessage,
                        initialBrokerage: brokerage,
                      ),
                    );
                  } else if (value == 'delete') {
                    await onDelete(brokerage);
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
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
    try {
      final result = await FilePicker.pickFiles(
        withData: true,
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );
      if (result == null) return;

      final file = result.files.single;
      if (file.bytes == null) {
        onUpdated('Unable to read the selected file. Please try again.');
        return;
      }

      final folderName = documentType.toLowerCase().replaceAll(' ', '_');
      final storagePath = storageService.buildLoadDocumentPath(
        companyName: load.companyName,
        driverName: load.driverName,
        yearWeek: load.yearWeek,
        loadNumber: load.loadNumber,
        documentType: folderName,
        fileName: file.name,
      );

      final upload = await storageService.uploadBytes(
        file.bytes!,
        storagePath,
        fileName: file.name,
      );
      final documentId = RealtimeService.instance.documentsRef.push().key!;
      final document = DocumentRecord(
        id: documentId,
        loadId: load.id,
        companyId: load.companyId,
        companyName: load.companyName,
        driverId: load.driverId,
        driverName: load.driverName,
        dispatcherId: load.dispatcherId,
        year: load.year,
        week: load.week,
        yearWeek: load.yearWeek,
        documentType: folderName,
        fileName: upload.fileName,
        storagePath: upload.storagePath,
        downloadUrl: upload.downloadUrl,
        uploadedBy: user.uid,
        uploadedAt: DateTime.now().toIso8601String(),
        verified: false,
        affectsStatus:
            folderName == 'rate_confirmation' ||
            folderName == 'bol' ||
            folderName == 'pod',
        notes: '',
      );
      await RealtimeService.instance.saveDocument(document);
      onUpdated('$documentType uploaded for ${load.loadNumber}');
      if (context.mounted) Navigator.of(context).pop();
    } catch (error) {
      onUpdated('Document upload failed: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountingDocTypes = const [
      'Invoice Copy',
      'Payment Support Document',
    ];
    final paperworkDocTypes = const [
      'Rate Confirmation',
      'POD',
      'BOL',
      'Carrier Packet',
      'Other',
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                load.loadNumber,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text('${load.routeSummary} • ${load.companyName}'),
              const SizedBox(height: 16),
              _LoadProgressTracker(load: load),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(label: Text('Operational: ${load.operationalStatus}')),
                  Chip(label: Text('Financial: ${load.financialStatus}')),
                  Chip(label: Text('Payment: ${load.paymentStatus}')),
                  Chip(label: Text('Paperwork: ${load.paperworkStatus}')),
                ],
              ),
              const SizedBox(height: 16),
              _DetailSection(
                title: 'Basic Information',
                rows: [
                  _detailRow('Load Number', load.loadNumber),
                  _detailRow('Year / Week', '${load.year} / ${load.yearWeek}'),
                  _detailRow('Operational Status', load.operationalStatus),
                  _detailRow('Financial Status', load.financialStatus),
                ],
              ),
              _DetailSection(
                title: 'Route Information',
                rows: [
                  _detailRow('Pickup', load.pickupLocation),
                  _detailRow('Delivery', load.deliveryLocation),
                  _detailRow('Route Summary', load.routeSummary),
                  _detailRow(
                    'Delivery DateTime',
                    load.deliveryDateTime.isEmpty
                        ? 'Not set'
                        : load.deliveryDateTime,
                  ),
                ],
              ),
              _DetailSection(
                title: 'Driver Information',
                rows: [
                  _detailRow('Driver', load.driverName),
                  _detailRow('Truck Number', load.truckNumber),
                  _detailRow('Dispatcher', load.dispatcherName),
                ],
              ),
              _DetailSection(
                title: 'Brokerage Information',
                rows: [
                  _detailRow('Brokerage', load.brokerageName),
                  _detailRow('MC', load.brokerageMc),
                  _detailRow(
                    'Broker Contact',
                    load.brokerContact.isEmpty ? 'N/A' : load.brokerContact,
                  ),
                ],
              ),
              _DetailSection(
                title: 'Financial Information',
                rows: [
                  _detailRow('Load Rate', _money(load.loadRate)),
                  _detailRow(
                    'Dispatch Fee %',
                    '${load.feePercentage.toStringAsFixed(2)}%',
                  ),
                  _detailRow(
                    'Dispatch Fee Amount',
                    _money(load.dispatchFeeAmount),
                  ),
                  _detailRow(
                    'Dispatcher Revenue',
                    _money(load.dispatcherRevenue),
                  ),
                ],
              ),
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
                          onPressed: () =>
                              _uploadDocument(context, documentType: type),
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
                            onPressed: () =>
                                _uploadDocument(context, documentType: type),
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
                stream: RealtimeService.instance.streamDocumentsForLoad(
                  load.id,
                ),
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
                              leading: const Icon(
                                Icons.insert_drive_file_outlined,
                              ),
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
              const SizedBox(height: 20),
              Text(
                'Activity Timeline',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              StreamBuilder<List<ActivityLogRecord>>(
                stream: RealtimeService.instance.streamActivityLogsForLoad(
                  load.id,
                ),
                builder: (context, snapshot) {
                  final logs = snapshot.data ?? const <ActivityLogRecord>[];
                  if (logs.isEmpty) {
                    return const Text('No activity recorded yet.');
                  }
                  return Column(
                    children: logs
                        .map(
                          (log) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(
                              Icons.timeline,
                              color: Color(0xFF8B6BFF),
                            ),
                            title: Text(log.message),
                            subtitle: Text(log.createdAt),
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

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.rows});

  final String title;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              ...rows,
            ],
          ),
        ),
      ),
    );
  }
}

Widget _detailRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(label, style: const TextStyle(color: Color(0xFF92A0C0))),
        ),
        Expanded(child: Text(value)),
      ],
    ),
  );
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
  bool _showPassword = false;

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
      final dispatcherId = role == AppRole.dispatcher
          ? 'disp_${DateTime.now().millisecondsSinceEpoch}'
          : '';
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
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _email,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              decoration: InputDecoration(
                labelText: 'Password',
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() => _showPassword = !_showPassword);
                  },
                  icon: Icon(
                    _showPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                ),
              ),
              obscureText: !_showPassword,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<AppRole>(
              initialValue: _role,
              items: AppRole.values
                  .map(
                    (role) =>
                        DropdownMenuItem(value: role, child: Text(role.label)),
                  )
                  .toList(),
              onChanged: (role) =>
                  setState(() => _role = role ?? AppRole.dispatcher),
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
          child: _saving
              ? const CircularProgressIndicator()
              : const Text('Create'),
        ),
      ],
    );
  }
}

class _CompanyFormDialog extends StatefulWidget {
  const _CompanyFormDialog({
    required this.onMessage,
    this.initialCompany,
  });

  final void Function(String message) onMessage;
  final Company? initialCompany;

  @override
  State<_CompanyFormDialog> createState() => _CompanyFormDialogState();
}

class _CompanyFormDialogState extends State<_CompanyFormDialog> {
  late final TextEditingController _name;
  late final TextEditingController _fee;
  late final TextEditingController _email;
  late final TextEditingController _terms;
  late final TextEditingController _notes;

  @override
  void initState() {
    super.initState();
    final company = widget.initialCompany;
    _name = TextEditingController(text: company?.name ?? '');
    _fee = TextEditingController(
      text: company == null ? '' : company.feePercentage.toString(),
    );
    _email = TextEditingController(text: company?.billingEmail ?? '');
    _terms = TextEditingController(text: company?.billingTerms ?? 'Net 15');
    _notes = TextEditingController(text: company?.notes ?? '');
  }

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
    if (_name.text.trim().isEmpty || (double.tryParse(_fee.text.trim()) ?? 0) <= 0) {
      widget.onMessage('Enter a company name and valid fee percentage.');
      return;
    }
    final id =
        widget.initialCompany?.id ??
        RealtimeService.instance.companiesRef.push().key!;
    final company = Company(
      id: id,
      name: _name.text.trim(),
      feePercentage: double.tryParse(_fee.text.trim()) ?? 0,
      billingEmail: _email.text.trim(),
      billingTerms: _terms.text.trim(),
      active: widget.initialCompany?.active ?? true,
      notes: _notes.text.trim(),
    );
    await RealtimeService.instance.saveCompany(company);
    widget.onMessage(
      widget.initialCompany == null
          ? '${company.name} added.'
          : '${company.name} updated.',
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initialCompany == null ? 'Add Company' : 'Edit Company'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Company Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _fee,
              decoration: const InputDecoration(labelText: 'Dispatch Fee %'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _email,
              decoration: const InputDecoration(labelText: 'Billing Email'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _terms,
              decoration: const InputDecoration(labelText: 'Billing Terms'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              decoration: const InputDecoration(labelText: 'Notes'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

class _BrokerageFormDialog extends StatefulWidget {
  const _BrokerageFormDialog({
    required this.onMessage,
    this.initialBrokerage,
  });

  final void Function(String message) onMessage;
  final Brokerage? initialBrokerage;

  @override
  State<_BrokerageFormDialog> createState() => _BrokerageFormDialogState();
}

class _BrokerageFormDialogState extends State<_BrokerageFormDialog> {
  late final TextEditingController _name;
  late final TextEditingController _mc;
  late final TextEditingController _contact;

  @override
  void initState() {
    super.initState();
    final brokerage = widget.initialBrokerage;
    _name = TextEditingController(text: brokerage?.name ?? '');
    _mc = TextEditingController(text: brokerage?.mc ?? '');
    _contact = TextEditingController(text: brokerage?.contact ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _mc.dispose();
    _contact.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty || _mc.text.trim().isEmpty) {
      widget.onMessage('Enter a brokerage name and MC number.');
      return;
    }
    final id =
        widget.initialBrokerage?.id ??
        RealtimeService.instance.brokeragesRef.push().key!;
    final brokerage = Brokerage(
      id: id,
      name: _name.text.trim(),
      mc: _mc.text.trim(),
      contact: _contact.text.trim(),
    );
    await RealtimeService.instance.saveBrokerage(brokerage);
    widget.onMessage(
      widget.initialBrokerage == null
          ? '${brokerage.name} added.'
          : '${brokerage.name} updated.',
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.initialBrokerage == null ? 'Add Brokerage' : 'Edit Brokerage',
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _mc,
            decoration: const InputDecoration(labelText: 'MC'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _contact,
            decoration: const InputDecoration(labelText: 'Contact'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

class _DriversPage extends StatelessWidget {
  const _DriversPage({required this.onMessage, required this.onDelete});

  final void Function(String message) onMessage;
  final Future<void> Function(DriverRecord driver) onDelete;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<DriverRecord>>(
      stream: RealtimeService.instance.streamDrivers(),
      builder: (context, snapshot) {
        final drivers = snapshot.data ?? const <DriverRecord>[];
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await showDialog<void>(
                    context: context,
                    builder: (context) => _DriverFormDialog(onMessage: onMessage),
                  );
                },
                icon: const Icon(Icons.person_add_alt_1_outlined),
                label: const Text('Add driver'),
              ),
            ),
            const SizedBox(height: 12),
            if (drivers.isEmpty)
              const _EmptyStateCard(
                title: 'No drivers available',
                subtitle: 'Add a driver to assign loads and track weekly earnings.',
              ),
            ...drivers.map(
              (driver) => Card(
                child: ListTile(
                  title: Text(driver.name),
                  subtitle: Text(
                    'Truck: ${driver.truckNumber.isEmpty ? 'N/A' : driver.truckNumber} • Phone: ${driver.phone.isEmpty ? 'N/A' : driver.phone}',
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'edit') {
                        await showDialog<void>(
                          context: context,
                          builder: (context) => _DriverFormDialog(
                            onMessage: onMessage,
                            initialDriver: driver,
                          ),
                        );
                      } else if (value == 'delete') {
                        await onDelete(driver);
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DocumentsPage extends StatelessWidget {
  const _DocumentsPage({
    required this.user,
    required this.onMessage,
    required this.onDeleteDocument,
  });

  final AppUser user;
  final void Function(String message) onMessage;
  final Future<void> Function(DocumentRecord document) onDeleteDocument;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<DocumentRecord>>(
      stream: RealtimeService.instance.streamDocuments(),
      builder: (context, snapshot) {
        final documents = (snapshot.data ?? const <DocumentRecord>[])
            .where((document) {
              if (user.isAdmin || user.isPaperwork || user.isAccountant) {
                return true;
              }
              return document.dispatcherId == user.dispatcherId;
            })
            .toList();
        if (documents.isEmpty) {
          return const Center(
            child: _EmptyStateCard(
              title: 'No documents found',
              subtitle: 'Upload paperwork or invoice files to see them here.',
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: documents.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final document = documents[index];
            return Card(
              child: ListTile(
                title: Text('${document.documentType} • ${document.fileName}'),
                subtitle: Text(
                  '${document.companyName} • ${document.driverName}\nUploaded ${document.uploadedAt}',
                ),
                isThreeLine: true,
                trailing: PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'open') {
                      final uri = Uri.tryParse(document.downloadUrl);
                      if (uri == null ||
                          !await launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          )) {
                        onMessage('Unable to open ${document.fileName}.');
                      }
                    } else if (value == 'edit') {
                      await showDialog<void>(
                        context: context,
                        builder: (context) => _DocumentNotesDialog(
                          document: document,
                          onMessage: onMessage,
                        ),
                      );
                    } else if (value == 'delete') {
                      await onDeleteDocument(document);
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'open', child: Text('View Document')),
                    PopupMenuItem(value: 'edit', child: Text('Edit Notes')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ReportsPage extends StatelessWidget {
  const _ReportsPage({
    required this.user,
    required this.loads,
    required this.invoices,
    required this.companies,
  });

  final AppUser user;
  final List<LoadItem> loads;
  final List<InvoiceRecord> invoices;
  final List<Company> companies;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _PageHero(
          title: 'Reports & Analytics',
          subtitle: 'Operational and financial trends across your current filters.',
          actionLabel: 'Live Data',
        ),
        const SizedBox(height: 16),
        ResponsiveGrid(
          children: [
            _SectionCard(
              title: 'Revenue Overview',
              child: SizedBox(
                height: 260,
                child: _MonthlyPerformanceLineChart(loads: loads),
              ),
            ),
            _SectionCard(
              title: 'Load Status Distribution',
              child: SizedBox(height: 260, child: _StatusPieChart(loads: loads)),
            ),
            _SectionCard(
              title: 'Company Comparison',
              child: SizedBox(
                height: 260,
                child: _RevenueByCompanyChart(loads: loads, companies: companies),
              ),
            ),
            _SectionCard(
              title: 'Billing by Company',
              child: SizedBox(
                height: 260,
                child: _BillingByCompanyChart(invoices: invoices),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SettingsPage extends StatelessWidget {
  const _SettingsPage({
    required this.user,
    required this.onOpenThemeSettings,
    required this.onMessage,
  });

  final AppUser user;
  final Future<void> Function() onOpenThemeSettings;
  final void Function(String message) onMessage;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: _MiniProfile(user: user),
            title: Text(user.name),
            subtitle: Text('${user.email}\n${user.role.label}'),
            isThreeLine: true,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('Appearance'),
            subtitle: const Text('Switch light, dark, or system mode'),
            trailing: const Icon(Icons.chevron_right),
            onTap: onOpenThemeSettings,
          ),
        ),
        const SizedBox(height: 12),
        const _EmptyStateCard(
          title: 'Settings',
          subtitle:
              'Additional user preferences and system controls can be expanded here without affecting operational workflows.',
        ),
      ],
    );
  }
}

class _ModernDashboard extends StatelessWidget {
  const _ModernDashboard({
    required this.user,
    required this.loads,
    required this.invoices,
    required this.onNavigate,
  });

  final AppUser user;
  final List<LoadItem> loads;
  final List<InvoiceRecord> invoices;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    final grossRevenue = loads.fold<double>(0, (sum, load) => sum + load.loadRate);
    final fees = loads.fold<double>(
      0,
      (sum, load) => sum + load.dispatchFeeAmount,
    );
    final activeLoads = loads
        .where((load) => load.operationalStatus != 'Delivered')
        .length;
    final invoicesPending = invoices
        .where((invoice) => invoice.paymentStatus != 'Paid')
        .length;
    final recentLoads = [...loads]
      ..sort((a, b) => b.createdDate.compareTo(a.createdDate));
    final driverTotals = <String, ({int count, double gross, double fee})>{};
    for (final load in loads) {
      final current =
          driverTotals[load.driverName] ?? (count: 0, gross: 0.0, fee: 0.0);
      driverTotals[load.driverName] = (
        count: current.count + 1,
        gross: current.gross + load.loadRate,
        fee: current.fee + load.dispatchFeeAmount,
      );
    }
    final driverRank = driverTotals.entries.toList()
      ..sort((a, b) => b.value.fee.compareTo(a.value.fee));
    final maxFee = driverRank.fold<double>(
      0,
      (max, entry) => entry.value.fee > max ? entry.value.fee : max,
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _PageHero(
          title: '${user.role.label} Dashboard',
          subtitle: 'Monitor loads, revenue, documents, and invoices from one workspace.',
          actionLabel: '${DateTime.now().month}/${DateTime.now().year}',
        ),
        const SizedBox(height: 16),
        ResponsiveGrid(
          children: [
            _SummaryCard(
              title: 'Gross Revenue',
              value: _money(grossRevenue),
              icon: Icons.attach_money_outlined,
            ),
            _SummaryCard(
              title: 'Dispatch Fees',
              value: _money(fees),
              icon: Icons.payments_outlined,
            ),
            _SummaryCard(
              title: 'Active Loads',
              value: '$activeLoads',
              icon: Icons.local_shipping_outlined,
            ),
            _SummaryCard(
              title: 'Invoices Pending',
              value: '$invoicesPending',
              icon: Icons.receipt_long_outlined,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Quick Actions',
          child: ResponsiveGrid(
            minItemWidth: 180,
            children: [
              _QuickActionCard(
                icon: Icons.add_circle_outline,
                title: 'Add Load',
                subtitle: 'Create a new load record',
                onTap: () => onNavigate('Add Load'),
              ),
              _QuickActionCard(
                icon: Icons.list_alt_outlined,
                title: 'View Loads',
                subtitle: 'Review and manage loads',
                onTap: () => onNavigate('Loads'),
              ),
              _QuickActionCard(
                icon: Icons.receipt_long_outlined,
                title: 'Generate Invoice',
                subtitle: 'Open invoice workflow',
                onTap: () => onNavigate('Invoices'),
              ),
              _QuickActionCard(
                icon: Icons.folder_copy_outlined,
                title: 'Upload Documents',
                subtitle: 'Review documents and paperwork',
                onTap: () => onNavigate('Documents'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ResponsiveGrid(
          children: [
            _SectionCard(
              title: 'Revenue Overview',
              child: SizedBox(
                height: 280,
                child: _MonthlyPerformanceLineChart(loads: loads),
              ),
            ),
            _SectionCard(
              title: 'Load Status Distribution',
              child: SizedBox(height: 280, child: _StatusPieChart(loads: loads)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ResponsiveGrid(
          children: [
            _SectionCard(
              title: 'Driver Performance',
              child: driverRank.isEmpty
                  ? const _EmptyStateCard(
                      title: 'No drivers available',
                      subtitle: 'Driver performance will appear as soon as loads are assigned.',
                    )
                  : Column(
                      children: driverRank.take(6).map((entry) {
                        final ratio = maxFee == 0 ? 0.0 : entry.value.fee / maxFee;
                        return _MetricBar(
                          label: entry.key,
                          subtitle:
                              '${entry.value.count} loads • Gross ${_money(entry.value.gross)} • Fee ${_money(entry.value.fee)}',
                          ratio: ratio,
                        );
                      }).toList(),
                    ),
            ),
            _SectionCard(
              title: 'Recent Loads',
              child: recentLoads.isEmpty
                  ? const _EmptyStateCard(
                      title: 'No loads found',
                      subtitle: 'Recent operational activity will appear here.',
                    )
                  : Column(
                      children: recentLoads.take(6).map((load) {
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.local_shipping_outlined),
                          title: Text(load.loadNumber),
                          subtitle: Text(
                            '${load.pickupLocation} → ${load.deliveryLocation}\n${load.companyName} • ${load.driverName}',
                          ),
                          isThreeLine: true,
                          trailing: Chip(label: Text(load.operationalStatus)),
                        );
                      }).toList(),
                    ),
            ),
          ],
        ),
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.dashboardColors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surfaceAlt,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: colors.primary),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(subtitle, style: TextStyle(color: colors.muted)),
          ],
        ),
      ),
    );
  }
}

class _MetricBar extends StatelessWidget {
  const _MetricBar({
    required this.label,
    required this.subtitle,
    required this.ratio,
  });

  final String label;
  final String subtitle;
  final double ratio;

  @override
  Widget build(BuildContext context) {
    final colors = context.dashboardColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(color: colors.muted, fontSize: 12)),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: ratio.clamp(0.0, 1.0),
            minHeight: 10,
            borderRadius: BorderRadius.circular(999),
          ),
        ],
      ),
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.dashboardColors;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surfaceAlt,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(subtitle, style: TextStyle(color: colors.muted)),
        ],
      ),
    );
  }
}

class _DriverFormDialog extends StatefulWidget {
  const _DriverFormDialog({
    required this.onMessage,
    this.initialDriver,
  });

  final void Function(String message) onMessage;
  final DriverRecord? initialDriver;

  @override
  State<_DriverFormDialog> createState() => _DriverFormDialogState();
}

class _DriverFormDialogState extends State<_DriverFormDialog> {
  late final TextEditingController _name;
  late final TextEditingController _truck;
  late final TextEditingController _phone;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initialDriver?.name ?? '');
    _truck = TextEditingController(
      text: widget.initialDriver?.truckNumber ?? '',
    );
    _phone = TextEditingController(text: widget.initialDriver?.phone ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _truck.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      widget.onMessage('Enter a driver name.');
      return;
    }
    final id =
        widget.initialDriver?.id ?? RealtimeService.instance.driversRef.push().key!;
    final driver = DriverRecord(
      id: id,
      name: _name.text.trim(),
      truckNumber: _truck.text.trim(),
      phone: _phone.text.trim(),
    );
    await RealtimeService.instance.saveDriver(driver);
    widget.onMessage(
      widget.initialDriver == null
          ? '${driver.name} added.'
          : '${driver.name} updated.',
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initialDriver == null ? 'Add Driver' : 'Edit Driver'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Driver Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _truck,
              decoration: const InputDecoration(labelText: 'Truck Number'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phone,
              decoration: const InputDecoration(labelText: 'Phone'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

class _DocumentNotesDialog extends StatefulWidget {
  const _DocumentNotesDialog({
    required this.document,
    required this.onMessage,
  });

  final DocumentRecord document;
  final void Function(String message) onMessage;

  @override
  State<_DocumentNotesDialog> createState() => _DocumentNotesDialogState();
}

class _DocumentNotesDialogState extends State<_DocumentNotesDialog> {
  late final TextEditingController _notes;

  @override
  void initState() {
    super.initState();
    _notes = TextEditingController(text: widget.document.notes);
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await RealtimeService.instance.updateDocument(widget.document.id, {
      'notes': _notes.text.trim(),
    });
    widget.onMessage('${widget.document.fileName} updated.');
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Document Notes'),
      content: TextField(
        controller: _notes,
        maxLines: 4,
        decoration: const InputDecoration(labelText: 'Notes'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

class _LoadFormDialog extends StatefulWidget {
  const _LoadFormDialog({
    required this.user,
    required this.companies,
    required this.brokerages,
    required this.onMessage,
    this.initialLoad,
  });

  final AppUser user;
  final List<Company> companies;
  final List<Brokerage> brokerages;
  final void Function(String message) onMessage;
  final LoadItem? initialLoad;

  @override
  State<_LoadFormDialog> createState() => _LoadFormDialogState();
}

class _LoadFormDialogState extends State<_LoadFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _loadNumber;
  late final TextEditingController _driverName;
  late final TextEditingController _driverPhone;
  late final TextEditingController _truckNumber;
  late final TextEditingController _pickup;
  late final TextEditingController _delivery;
  late final TextEditingController _brokerContact;
  late final TextEditingController _rate;
  late final TextEditingController _notes;
  Company? _company;
  Brokerage? _brokerage;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final load = widget.initialLoad;
    _loadNumber = TextEditingController(text: load?.loadNumber ?? '');
    _driverName = TextEditingController(text: load?.driverName ?? '');
    _driverPhone = TextEditingController();
    _truckNumber = TextEditingController(text: load?.truckNumber ?? '');
    _pickup = TextEditingController(text: load?.pickupLocation ?? '');
    _delivery = TextEditingController(text: load?.deliveryLocation ?? '');
    _brokerContact = TextEditingController(text: load?.brokerContact ?? '');
    _rate = TextEditingController(
      text: load == null ? '' : load.loadRate.toStringAsFixed(0),
    );
    _notes = TextEditingController(text: load?.notes ?? '');
    for (final company in widget.companies) {
      if (company.id == load?.companyId) {
        _company = company;
        break;
      }
    }
    for (final brokerage in widget.brokerages) {
      if (brokerage.id == load?.brokerageId) {
        _brokerage = brokerage;
        break;
      }
    }
  }

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
      widget.onMessage('Select a company and brokerage first.');
      return;
    }
    setState(() => _saving = true);
    try {
      final existing = widget.initialLoad;
      final duplicate = await RealtimeService.instance.loadNumberExists(
        _loadNumber.text.trim(),
        excludingId: existing?.id,
      );
      if (duplicate) {
        widget.onMessage('Load number must be unique.');
        return;
      }

      final driverId = await RealtimeService.instance.upsertDriver(
        name: _driverName.text.trim(),
        truckNumber: _truckNumber.text.trim(),
        phone: _driverPhone.text.trim(),
        driverId: existing?.driverId,
      );
      final rate = double.tryParse(_rate.text.trim()) ?? 0;
      final feePercentage = _company!.feePercentage;
      final dispatchFeeAmount = rate * (feePercentage / 100);
      final now = DateTime.now().toIso8601String();
      final weekParts = RealtimeService.instance.isoWeekParts(DateTime.now());

      final load =
          existing?.copyWith(
            loadNumber: _loadNumber.text.trim(),
            companyId: _company!.id,
            companyName: _company!.name,
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
            notes: _notes.text.trim(),
            updatedDate: now,
            year: weekParts.year,
            week: weekParts.week,
            yearWeek: weekParts.yearWeek,
          ) ??
          LoadItem(
            id: RealtimeService.instance.loadsRef.push().key!,
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
            operationalStatus: 'New',
            financialStatus: 'Not Invoiced',
            invoiceStatus: 'Not Invoiced',
            paymentStatus: 'Unpaid',
            paperworkStatus: 'Incomplete',
            notes: _notes.text.trim(),
            createdBy: widget.user.uid,
            createdDate: now,
            updatedDate: now,
            year: weekParts.year,
            week: weekParts.week,
            yearWeek: weekParts.yearWeek,
            deliveryDateTime: '',
            rateConfirmationUploaded: false,
            podUploaded: false,
            podUploadedAt: '',
            podDelayFlag: false,
            bolUploaded: false,
            missingDocumentsCount: 3,
          );

      await RealtimeService.instance.saveLoad(
        load,
        logCreation: existing == null,
      );
      widget.onMessage(
        existing == null
            ? 'Load ${load.loadNumber} created.'
            : 'Load ${load.loadNumber} updated.',
      );
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initialLoad == null ? 'Add Load' : 'Edit Load'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                      .map(
                        (company) => DropdownMenuItem(
                          value: company,
                          child: Text(company.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _company = value),
                  decoration: const InputDecoration(labelText: 'Company'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<Brokerage>(
                  initialValue: _brokerage,
                  items: widget.brokerages
                      .map(
                        (brokerage) => DropdownMenuItem(
                          value: brokerage,
                          child: Text(brokerage.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _brokerage = value),
                  decoration: const InputDecoration(labelText: 'Brokerage'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _driverName,
                  decoration: const InputDecoration(labelText: 'Driver Name'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _truckNumber,
                  decoration: const InputDecoration(labelText: 'Truck Number'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _pickup,
                  decoration: const InputDecoration(labelText: 'Pickup'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _delivery,
                  decoration: const InputDecoration(labelText: 'Delivery'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _rate,
                  decoration: const InputDecoration(labelText: 'Load Rate'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notes,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Notes'),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
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
    final colors = context.dashboardColors;
    return SizedBox(
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
                  gradient: LinearGradient(
                    colors: [
                      colors.primary.withValues(alpha: 0.18),
                      colors.secondary.withValues(alpha: 0.22),
                    ],
                  ),
                ),
                child: Icon(icon, color: colors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: colors.muted),
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
    final colors = context.dashboardColors;
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
                    style: TextStyle(
                      color: colors.info,
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
    final colors = context.dashboardColors;
    final mobile = AppBreakpoints.isMobile(context);
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: mobile ? double.infinity : null,
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
              Text(subtitle, style: TextStyle(color: colors.muted)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: colors.surfaceAlt,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.border),
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
      'Pending Paperwork': loads
          .where((l) => l.paperworkStatus != 'Complete')
          .length,
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
    final recent = [...loads]
      ..sort((a, b) => b.createdDate.compareTo(a.createdDate));
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
                    Text(
                      load.loadNumber,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${load.pickupLocation} → ${load.deliveryLocation}',
                      style: const TextStyle(
                        color: Color(0xFF92A0C0),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
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
  const _RevenueByCompanyChart({required this.loads, required this.companies});

  final List<LoadItem> loads;
  final List<Company> companies;

  @override
  Widget build(BuildContext context) {
    final totals = <String, double>{};
    for (final load in loads) {
      totals[load.companyName] =
          (totals[load.companyName] ?? 0) + load.dispatcherRevenue;
    }
    final entries = totals.entries.toList();
    if (entries.isEmpty) return const Center(child: Text('No chart data'));

    final maxValue = entries.fold<double>(
      0,
      (max, entry) => entry.value > max ? entry.value : max,
    );
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
                if (index < 0 || index >= entries.length) {
                  return const SizedBox();
                }
                final label = entries[index].key;
                return Text(
                  label.length > 8 ? label.substring(0, 8) : label,
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: true),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
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
      totals[load.companyName] =
          (totals[load.companyName] ?? 0) + load.dispatchFeeAmount;
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
            operationalStatus: '',
            financialStatus: '',
            invoiceStatus: '',
            paymentStatus: '',
            paperworkStatus: '',
            notes: '',
            createdBy: '',
            createdDate: '',
            updatedDate: '',
            year: 0,
            week: 0,
            yearWeek: '',
            deliveryDateTime: '',
            rateConfirmationUploaded: false,
            podUploaded: false,
            podUploadedAt: '',
            podDelayFlag: false,
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
    final entries = totals.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    if (entries.isEmpty) return const Center(child: Text('No invoice data'));

    final maxValue = entries.fold<double>(
      0,
      (max, entry) => entry.value > max ? entry.value : max,
    );
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
                if (index < 0 || index >= entries.length) {
                  return const SizedBox();
                }
                return Text(entries[index].key.substring(5));
              },
            ),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: true),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
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
    final delivered = loads
        .where((load) => load.status == 'Delivered')
        .length
        .toDouble();
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

    final complete = loads
        .where((load) => load.paperworkComplete)
        .length
        .toDouble();
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

    final keys = {...grossByMonth.keys, ...revenueByMonth.keys}.toList()
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
          getDrawingHorizontalLine: (value) =>
              const FlLine(color: Color(0xFF1E2940), strokeWidth: 1),
          getDrawingVerticalLine: (value) =>
              const FlLine(color: Color(0x00000000)),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
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
                    style: const TextStyle(
                      color: Color(0xFF7685AA),
                      fontSize: 11,
                    ),
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
    final paid = invoices
        .where((invoice) => invoice.paymentStatus == 'Paid')
        .length
        .toDouble();
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
      totals[invoice.companyName] =
          (totals[invoice.companyName] ?? 0) + invoice.invoiceAmount;
    }
    final entries = totals.entries.toList();
    if (entries.isEmpty) return const Center(child: Text('No billing data'));
    final maxY = entries.fold<double>(
      0,
      (max, e) => e.value > max ? e.value : max,
    );

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
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: true),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= entries.length) {
                  return const SizedBox();
                }
                final label = entries[index].key;
                return Text(
                  label.length > 7 ? label.substring(0, 7) : label,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF7685AA),
                  ),
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
    final rc = loads
        .where((l) => !l.rateConfirmationUploaded)
        .length
        .toDouble();
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
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: true),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= entries.length) {
                  return const SizedBox();
                }
                return Text(
                  entries[index].$1,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF7685AA),
                  ),
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
    final flagged = loads
        .where((load) => load.missingDocumentsCount > 0)
        .take(4)
        .toList();
    if (flagged.isEmpty) return const Text('No missing-document alerts.');
    return Column(
      children: flagged.map((load) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFFF8A65),
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      load.loadNumber,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      '${load.missingDocumentsCount} missing docs',
                      style: const TextStyle(
                        color: Color(0xFF92A0C0),
                        fontSize: 12,
                      ),
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
      totals[load.dispatcherName] =
          (totals[load.dispatcherName] ?? 0) + load.dispatcherRevenue;
    }
    final entries = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (entries.isEmpty) return const Center(child: Text('No dispatcher data'));
    final maxY = entries.fold<double>(
      0,
      (max, e) => e.value > max ? e.value : max,
    );

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
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: true),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= entries.length) {
                  return const SizedBox();
                }
                final name = entries[index].key;
                return Text(
                  name.length > 8 ? name.substring(0, 8) : name,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF7685AA),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadProgressTracker extends StatelessWidget {
  const _LoadProgressTracker({required this.load});

  final LoadItem load;

  @override
  Widget build(BuildContext context) {
    const stages = ['New', 'Booked', 'Picked', 'Delivered', 'Closed'];
    final currentIndex = stages
        .indexOf(load.operationalStatus)
        .clamp(0, stages.length - 1);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Progress Tracker',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                for (var i = 0; i < stages.length; i++) ...[
                  Expanded(
                    child: Column(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: i <= currentIndex
                                ? const Color(0xFF6C4DFF)
                                : const Color(0xFF1E2940),
                          ),
                          child: Icon(
                            i <= currentIndex
                                ? Icons.check
                                : Icons.circle_outlined,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          stages[i],
                          style: const TextStyle(fontSize: 11),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  if (i != stages.length - 1)
                    Expanded(
                      child: Container(
                        height: 3,
                        margin: const EdgeInsets.only(bottom: 28),
                        color: i < currentIndex
                            ? const Color(0xFF6C4DFF)
                            : const Color(0xFF1E2940),
                      ),
                    ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DispatcherNotifications extends StatelessWidget {
  const _DispatcherNotifications({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AppNotification>>(
      stream: RealtimeService.instance.streamNotificationsForUser(userId),
      builder: (context, snapshot) {
        final items = snapshot.data ?? const <AppNotification>[];
        if (items.isEmpty) {
          return const Text('No alerts for this dispatcher right now.');
        }
        return Column(
          children: items.take(4).map((item) {
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                item.read
                    ? Icons.notifications_none
                    : Icons.notification_important_outlined,
                color: item.read
                    ? const Color(0xFF92A0C0)
                    : const Color(0xFFFF8A65),
              ),
              title: Text(item.title),
              subtitle: Text(item.message),
              trailing: item.read
                  ? null
                  : TextButton(
                      onPressed: () => RealtimeService.instance
                          .markNotificationRead(item.id),
                      child: const Text('Mark read'),
                    ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _WeeklyDriverEarningsChart extends StatelessWidget {
  const _WeeklyDriverEarningsChart({required this.loads});

  final List<LoadItem> loads;

  @override
  Widget build(BuildContext context) {
    if (loads.isEmpty) {
      return const Center(child: Text('No weekly driver data'));
    }
    final totals = <String, ({double gross, double fee, int count})>{};
    for (final load in loads) {
      final current =
          totals[load.driverName] ?? (gross: 0.0, fee: 0.0, count: 0);
      totals[load.driverName] = (
        gross: current.gross + load.loadRate,
        fee: current.fee + load.dispatchFeeAmount,
        count: current.count + 1,
      );
    }
    final entries = totals.entries.toList()
      ..sort((a, b) => b.value.fee.compareTo(a.value.fee));
    final maxY = entries.fold<double>(
      0,
      (max, entry) => entry.value.fee > max ? entry.value.fee : max,
    );
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
                  toY: entries[i].value.fee,
                  width: 18,
                  color: const Color(0xFF19D3C5),
                  borderRadius: BorderRadius.circular(6),
                ),
              ],
            ),
        ],
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: true),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= entries.length) {
                  return const SizedBox();
                }
                final name = entries[index].key;
                return Text(
                  name.length > 8 ? name.substring(0, 8) : name,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF7685AA),
                  ),
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
