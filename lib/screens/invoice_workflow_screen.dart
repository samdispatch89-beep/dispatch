import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/app_user.dart';
import '../models/company.dart';
import '../models/invoice_record.dart';
import '../models/load_item.dart';
import '../responsive/breakpoints.dart';
import '../services/automation_service.dart';
import '../shared/widgets/responsive_grid.dart';
import '../shared/widgets/responsive_page_container.dart';
import '../theme/app_colors.dart';

class InvoiceWorkflowScreen extends StatefulWidget {
  const InvoiceWorkflowScreen({
    super.key,
    required this.user,
    required this.companies,
    required this.loads,
    required this.invoices,
    required this.onMessage,
    required this.onMarkSent,
    required this.onMarkPaid,
  });

  final AppUser user;
  final List<Company> companies;
  final List<LoadItem> loads;
  final List<InvoiceRecord> invoices;
  final void Function(String message) onMessage;
  final Future<void> Function(InvoiceRecord invoice) onMarkSent;
  final Future<void> Function(InvoiceRecord invoice) onMarkPaid;

  @override
  State<InvoiceWorkflowScreen> createState() => _InvoiceWorkflowScreenState();
}

class _InvoiceWorkflowScreenState extends State<InvoiceWorkflowScreen> {
  final AutomationService _automation = AutomationService();

  Company? _company;
  DateTimeRange? _dateRange;
  List<LoadItem> _companyRangeLoads = const [];
  List<LoadItem> _previewLoads = const [];
  List<DriverChoice> _driverChoices = const [];
  Set<String> _selectedDriverIds = <String>{};
  Map<String, dynamic>? _generationResult;
  bool _fetchingDrivers = false;
  bool _generating = false;
  String? _validationMessage;
  int _step = 0;

  String _fmt(DateTime value) => DateFormat('yyyy-MM-dd').format(value);

  List<LoadItem> _filterLoads({
    required Company company,
    required DateTimeRange range,
    required Set<String> driverIds,
  }) {
    return widget.loads.where((load) {
      if (load.companyId != company.id) return false;
      final loadDate = DateTime.tryParse(load.date);
      if (loadDate == null) return false;
      final normalized = DateTime(loadDate.year, loadDate.month, loadDate.day);
      final start = DateTime(
        range.start.year,
        range.start.month,
        range.start.day,
      );
      final end = DateTime(range.end.year, range.end.month, range.end.day);
      final inRange = !normalized.isBefore(start) && !normalized.isAfter(end);
      if (!inRange) return false;
      if (driverIds.isEmpty) return true;
      return driverIds.contains(load.driverId);
    }).toList()..sort((a, b) => a.loadNumber.compareTo(b.loadNumber));
  }

  Future<void> _fetchDrivers() async {
    if (_company == null || _dateRange == null) {
      setState(
        () => _validationMessage = 'Select a company and date range first.',
      );
      return;
    }
    if (_dateRange!.start.isAfter(_dateRange!.end)) {
      setState(
        () => _validationMessage = 'Start date must be before end date.',
      );
      return;
    }

    setState(() {
      _fetchingDrivers = true;
      _validationMessage = null;
      _generationResult = null;
    });

    try {
      final loads = _filterLoads(
        company: _company!,
        range: _dateRange!,
        driverIds: const {},
      );

      if (loads.isEmpty) {
        setState(() {
          _companyRangeLoads = const [];
          _previewLoads = const [];
          _driverChoices = const [];
          _selectedDriverIds = <String>{};
          _step = 0;
          _validationMessage =
              'No loads found for the selected company and date range.';
        });
        return;
      }

      final driversById = <String, DriverChoice>{};
      for (final load in loads) {
        driversById.putIfAbsent(
          load.driverId,
          () => DriverChoice(
            driverId: load.driverId,
            driverName: load.driverName.isEmpty
                ? 'Unknown Driver'
                : load.driverName,
            totalLoads: 0,
          ),
        );
        driversById[load.driverId] = driversById[load.driverId]!.copyWith(
          totalLoads: driversById[load.driverId]!.totalLoads + 1,
        );
      }

      final choices = driversById.values.toList()
        ..sort((a, b) => a.driverName.compareTo(b.driverName));

      setState(() {
        _companyRangeLoads = loads;
        _driverChoices = choices;
        _selectedDriverIds = choices.map((driver) => driver.driverId).toSet();
        _previewLoads = loads;
        _step = 1;
      });
    } finally {
      if (mounted) {
        setState(() => _fetchingDrivers = false);
      }
    }
  }

  void _applyDriverSelection() {
    if (_company == null || _dateRange == null) return;
    final previewLoads = _filterLoads(
      company: _company!,
      range: _dateRange!,
      driverIds: _selectedDriverIds,
    );
    setState(() {
      _previewLoads = previewLoads;
      _validationMessage = previewLoads.isEmpty
          ? 'No loads remain after applying the selected drivers.'
          : null;
      _step = previewLoads.isEmpty ? 1 : 2;
    });
  }

  Future<void> _generateInvoice() async {
    if (_company == null || _dateRange == null) {
      setState(
        () => _validationMessage = 'Complete the invoice filters first.',
      );
      return;
    }
    if (_previewLoads.isEmpty) {
      setState(
        () => _validationMessage = 'There are no loads available to invoice.',
      );
      return;
    }

    setState(() {
      _generating = true;
      _validationMessage = null;
    });

    try {
      final result = await _automation.generateCompanyInvoice(
        companyId: _company!.id,
        startDate: _fmt(_dateRange!.start),
        endDate: _fmt(_dateRange!.end),
        driverIds: _selectedDriverIds.toList(),
        agentName: widget.user.name,
      );
      setState(() {
        _generationResult = result;
        _step = 3;
      });
      widget.onMessage(
        result['existing'] == true
            ? 'Existing invoice ${result['invoiceNumber']} loaded.'
            : 'Invoice ${result['invoiceNumber']} generated successfully.',
      );
    } catch (error) {
      setState(() {
        _validationMessage = 'Invoice generation failed. $error';
      });
    } finally {
      if (mounted) {
        setState(() => _generating = false);
      }
    }
  }

  InvoiceRecord? get _resultInvoice {
    final id = _generationResult?['invoiceId']?.toString();
    if (id == null || id.isEmpty) return null;
    for (final invoice in widget.invoices) {
      if (invoice.id == id) return invoice;
    }
    return null;
  }

  double get _previewGross =>
      _previewLoads.fold<double>(0, (sum, load) => sum + load.loadRate);

  double get _previewDispatchFee => _previewLoads.fold<double>(
    0,
    (sum, load) => sum + load.dispatchFeeAmount,
  );

  @override
  Widget build(BuildContext context) {
    return ResponsivePageContainer(
      child: ListView(
        padding: EdgeInsets.all(AppBreakpoints.pagePadding(context)),
        children: [
          _WorkflowHeader(
            step: _step,
            onReset: () {
              setState(() {
                _step = 0;
                _companyRangeLoads = const [];
                _previewLoads = const [];
                _driverChoices = const [];
                _selectedDriverIds = <String>{};
                _generationResult = null;
                _validationMessage = null;
              });
            },
          ),
          if (_validationMessage != null) ...[
            const SizedBox(height: 12),
            _InlineMessage(message: _validationMessage!),
          ],
          const SizedBox(height: 16),
          InvoiceFilterScreen(
            companies: widget.companies,
            selectedCompany: _company,
            dateRange: _dateRange,
            loading: _fetchingDrivers,
            onCompanyChanged: (company) => setState(() => _company = company),
            onDateRangeChanged: (range) => setState(() => _dateRange = range),
            onFetchDrivers: _fetchDrivers,
          ),
          if (_step >= 1) ...[
            const SizedBox(height: 16),
            DriverSelectionScreen(
              drivers: _driverChoices,
              selectedDriverIds: _selectedDriverIds,
              totalLoads: _companyRangeLoads.length,
              onSelectionChanged: (driverId, selected) {
                setState(() {
                  if (selected) {
                    _selectedDriverIds.add(driverId);
                  } else {
                    _selectedDriverIds.remove(driverId);
                  }
                });
              },
              onSelectAll: () {
                setState(() {
                  _selectedDriverIds = _driverChoices
                      .map((driver) => driver.driverId)
                      .toSet();
                });
              },
              onContinue: _applyDriverSelection,
            ),
          ],
          if (_step >= 2) ...[
            const SizedBox(height: 16),
            InvoicePreviewScreen(
              loads: _previewLoads,
              totalGross: _previewGross,
              totalDispatchFee: _previewDispatchFee,
              generating: _generating,
              onGenerate: _generateInvoice,
            ),
          ],
          if (_step >= 3) ...[
            const SizedBox(height: 16),
            InvoiceResultScreen(
              result: _generationResult ?? const {},
              invoice: _resultInvoice,
              onViewPdf: () async {
                final url =
                    (_resultInvoice?.invoiceFileUrl ??
                            _generationResult?['invoiceFileUrl']?.toString() ??
                            '')
                        .trim();
                if (url.isEmpty) {
                  widget.onMessage(
                    'No PDF URL is available for this invoice yet.',
                  );
                  return;
                }
                final uri = Uri.tryParse(url);
                if (uri == null ||
                    !await launchUrl(
                      uri,
                      mode: LaunchMode.externalApplication,
                    )) {
                  widget.onMessage('Unable to open the invoice PDF.');
                }
              },
              onDownloadPdf: () async {
                final url =
                    (_resultInvoice?.invoiceFileUrl ??
                            _generationResult?['invoiceFileUrl']?.toString() ??
                            '')
                        .trim();
                if (url.isEmpty) {
                  widget.onMessage('No invoice PDF is available to download.');
                  return;
                }
                final uri = Uri.tryParse(url);
                if (uri == null ||
                    !await launchUrl(
                      uri,
                      mode: LaunchMode.externalApplication,
                    )) {
                  widget.onMessage('Unable to open the invoice download link.');
                }
              },
              onMarkSent: _resultInvoice == null
                  ? null
                  : () async {
                      await widget.onMarkSent(_resultInvoice!);
                      widget.onMessage(
                        '${_resultInvoice!.invoiceNumber} marked sent.',
                      );
                    },
              onMarkPaid: _resultInvoice == null
                  ? null
                  : () async {
                      await widget.onMarkPaid(_resultInvoice!);
                      widget.onMessage(
                        '${_resultInvoice!.invoiceNumber} marked paid.',
                      );
                    },
            ),
          ],
        ],
      ),
    );
  }
}

class InvoiceFilterScreen extends StatelessWidget {
  const InvoiceFilterScreen({
    super.key,
    required this.companies,
    required this.selectedCompany,
    required this.dateRange,
    required this.loading,
    required this.onCompanyChanged,
    required this.onDateRangeChanged,
    required this.onFetchDrivers,
  });

  final List<Company> companies;
  final Company? selectedCompany;
  final DateTimeRange? dateRange;
  final bool loading;
  final ValueChanged<Company?> onCompanyChanged;
  final ValueChanged<DateTimeRange?> onDateRangeChanged;
  final VoidCallback onFetchDrivers;

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('yyyy-MM-dd');
    final isMobile = AppBreakpoints.isMobile(context);
    Company? resolvedCompany;
    if (selectedCompany != null) {
      for (final company in companies) {
        if (company.id == selectedCompany!.id) {
          resolvedCompany = company;
          break;
        }
      }
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Invoice Filter Screen',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Choose the company and weekly date range first. Then fetch the drivers who ran loads in that period.',
            ),
            const SizedBox(height: 16),
            if (isMobile) ...[
              DropdownButtonFormField<Company>(
                initialValue: resolvedCompany,
                items: companies
                    .where((company) => company.active)
                    .map(
                      (company) => DropdownMenuItem<Company>(
                        value: company,
                        child: Text(company.name),
                      ),
                    )
                    .toList(),
                onChanged: onCompanyChanged,
                decoration: const InputDecoration(labelText: 'Company'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  final now = DateTime.now();
                  final range = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(now.year - 2),
                    lastDate: DateTime(now.year + 2),
                    initialDateRange: dateRange,
                  );
                  onDateRangeChanged(range);
                },
                icon: const Icon(Icons.date_range_outlined),
                label: Text(
                  dateRange == null
                      ? 'Select Date Range'
                      : '${formatter.format(dateRange!.start)} → ${formatter.format(dateRange!.end)}',
                ),
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<Company>(
                      initialValue: resolvedCompany,
                      items: companies
                          .where((company) => company.active)
                          .map(
                            (company) => DropdownMenuItem<Company>(
                              value: company,
                              child: Text(company.name),
                            ),
                          )
                          .toList(),
                      onChanged: onCompanyChanged,
                      decoration: const InputDecoration(labelText: 'Company'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final now = DateTime.now();
                        final range = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(now.year - 2),
                          lastDate: DateTime(now.year + 2),
                          initialDateRange: dateRange,
                        );
                        onDateRangeChanged(range);
                      },
                      icon: const Icon(Icons.date_range_outlined),
                      label: Text(
                        dateRange == null
                            ? 'Select Date Range'
                            : '${formatter.format(dateRange!.start)} → ${formatter.format(dateRange!.end)}',
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: loading ? null : onFetchDrivers,
                icon: loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.people_outline),
                label: const Text('Fetch Drivers'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DriverSelectionScreen extends StatelessWidget {
  const DriverSelectionScreen({
    super.key,
    required this.drivers,
    required this.selectedDriverIds,
    required this.totalLoads,
    required this.onSelectionChanged,
    required this.onSelectAll,
    required this.onContinue,
  });

  final List<DriverChoice> drivers;
  final Set<String> selectedDriverIds;
  final int totalLoads;
  final void Function(String driverId, bool selected) onSelectionChanged;
  final VoidCallback onSelectAll;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Driver Selection Screen',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Found $totalLoads loads and ${drivers.length} drivers in the selected period.',
            ),
            const SizedBox(height: 12),
            if (drivers.isEmpty)
              const _EmptyBlock(
                title: 'No drivers found',
                subtitle:
                    'No driver records matched the selected company and date range.',
              )
            else ...[
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: onSelectAll,
                  child: const Text('Select All Drivers'),
                ),
              ),
              ...drivers.map(
                (driver) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: CheckboxListTile(
                    value: selectedDriverIds.contains(driver.driverId),
                    onChanged: (selected) =>
                        onSelectionChanged(driver.driverId, selected ?? false),
                    title: Text(driver.driverName),
                    subtitle: Text('${driver.totalLoads} loads in range'),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: onContinue,
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('Preview Invoice'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class InvoicePreviewScreen extends StatelessWidget {
  const InvoicePreviewScreen({
    super.key,
    required this.loads,
    required this.totalGross,
    required this.totalDispatchFee,
    required this.generating,
    required this.onGenerate,
  });

  final List<LoadItem> loads;
  final double totalGross;
  final double totalDispatchFee;
  final bool generating;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '\$');
    final colors = context.dashboardColors;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Invoice Preview Screen',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Review the filtered loads before generating the invoice PDF.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            if (loads.isEmpty)
              const _EmptyBlock(
                title: 'No loads to preview',
                subtitle:
                    'Adjust the selected drivers or date range, then try again.',
              )
            else ...[
              ResponsiveGrid(
                minItemWidth: 170,
                children: [
                  _PreviewStat(label: 'Loads', value: '${loads.length}'),
                  _PreviewStat(
                    label: 'Gross',
                    value: currency.format(totalGross),
                  ),
                  _PreviewStat(
                    label: 'Dispatch Fee',
                    value: currency.format(totalDispatchFee),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: colors.border),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    for (var index = 0; index < loads.length; index++) ...[
                      ListTile(
                        title: Text(
                          '${loads[index].loadNumber} • ${loads[index].driverName}',
                        ),
                        subtitle: Text(
                          '${loads[index].pickupLocation} → ${loads[index].deliveryLocation}\n'
                          'Gross: ${currency.format(loads[index].loadRate)} • Fee: ${currency.format(loads[index].dispatchFeeAmount)} • Status: ${loads[index].operationalStatus}',
                        ),
                        isThreeLine: true,
                      ),
                      if (index != loads.length - 1)
                        Divider(height: 1, color: colors.border),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: generating ? null : onGenerate,
                  icon: generating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('Generate Invoice'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class InvoiceResultScreen extends StatelessWidget {
  const InvoiceResultScreen({
    super.key,
    required this.result,
    required this.invoice,
    required this.onViewPdf,
    required this.onDownloadPdf,
    required this.onMarkSent,
    required this.onMarkPaid,
  });

  final Map<String, dynamic> result;
  final InvoiceRecord? invoice;
  final Future<void> Function() onViewPdf;
  final Future<void> Function() onDownloadPdf;
  final Future<void> Function()? onMarkSent;
  final Future<void> Function()? onMarkPaid;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '\$');
    final totalGross =
        double.tryParse(
          '${result['totalGross'] ?? invoice?.totalGross ?? 0}',
        ) ??
        0;
    final totalAmount =
        double.tryParse(
          '${result['totalAmount'] ?? invoice?.invoiceAmount ?? 0}',
        ) ??
        0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Invoice Result Screen',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Invoice ${result['invoiceNumber'] ?? invoice?.invoiceNumber ?? ''} is ready.',
            ),
            const SizedBox(height: 16),
            ResponsiveGrid(
              minItemWidth: 180,
              children: [
                _PreviewStat(
                  label: 'Total Gross',
                  value: currency.format(totalGross),
                ),
                _PreviewStat(
                  label: 'Total Amount',
                  value: currency.format(totalAmount),
                ),
                _PreviewStat(
                  label: 'Status',
                  value: invoice?.paymentStatus == 'Paid'
                      ? 'Paid'
                      : invoice?.invoiceStatus ?? 'Generated',
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: onViewPdf,
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('View PDF'),
                ),
                OutlinedButton.icon(
                  onPressed: onDownloadPdf,
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Download PDF'),
                ),
                ElevatedButton.icon(
                  onPressed: onMarkSent,
                  icon: const Icon(Icons.send_outlined),
                  label: const Text('Mark as Sent'),
                ),
                ElevatedButton.icon(
                  onPressed: onMarkPaid,
                  icon: const Icon(Icons.verified_outlined),
                  label: const Text('Mark as Paid'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkflowHeader extends StatelessWidget {
  const _WorkflowHeader({required this.step, required this.onReset});

  final int step;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    const labels = ['1. Filters', '2. Drivers', '3. Preview', '4. Result'];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < labels.length; i++)
                  Chip(
                    label: Text(labels[i]),
                    backgroundColor: i <= step
                        ? Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.22)
                        : null,
                  ),
              ],
            ),
            TextButton.icon(
              onPressed: onReset,
              icon: const Icon(Icons.refresh_outlined),
              label: const Text('Reset'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewStat extends StatelessWidget {
  const _PreviewStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.dashboardColors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: colors.muted)),
          const SizedBox(height: 6),
          Text(value, style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
    );
  }
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.dashboardColors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.error.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.error.withValues(alpha: 0.35)),
      ),
      child: Text(message, style: TextStyle(color: colors.error)),
    );
  }
}

class _EmptyBlock extends StatelessWidget {
  const _EmptyBlock({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.dashboardColors;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
        color: colors.surfaceAlt,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(subtitle, style: TextStyle(color: colors.muted)),
        ],
      ),
    );
  }
}

class DriverChoice {
  const DriverChoice({
    required this.driverId,
    required this.driverName,
    required this.totalLoads,
  });

  final String driverId;
  final String driverName;
  final int totalLoads;

  DriverChoice copyWith({
    String? driverId,
    String? driverName,
    int? totalLoads,
  }) {
    return DriverChoice(
      driverId: driverId ?? this.driverId,
      driverName: driverName ?? this.driverName,
      totalLoads: totalLoads ?? this.totalLoads,
    );
  }
}
