import 'package:flutter/material.dart';
import 'package:wachbuch_mobile/theme/design_tokens.dart';
import 'package:wachbuch_mobile/ui/empty_state.dart';
import 'package:wachbuch_mobile/ui/section_title.dart';
import 'package:wachbuch_mobile/l10n/generated/app_localizations.dart';
import 'package:wachbuch_mobile/api/client.dart';
import 'package:wachbuch_mobile/models/kaffeekasse.dart';
import 'package:wachbuch_mobile/state/coffee_state.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wachbuch_mobile/ui/copy_button.dart';
import 'package:wachbuch_mobile/ui/error_banner.dart';
import 'package:wachbuch_mobile/ui/layout.dart';

class KaffeekasseScreen extends StatefulWidget {
  const KaffeekasseScreen({
    super.key,
    required this.api,
    this.state,
  });

  final WachbuchApi api;
  final CoffeeState? state;

  @override
  State<KaffeekasseScreen> createState() => _KaffeekasseScreenState();
}

class _KaffeekasseScreenState extends State<KaffeekasseScreen> {
  late final CoffeeState _state;
  late final bool _ownsState;

  @override
  void initState() {
    super.initState();
    _state = widget.state ?? CoffeeState(api: widget.api);
    _ownsState = widget.state == null;
    _state.addListener(_onStateChanged);
    _state.reload();
  }

  @override
  void dispose() {
    _state.removeListener(_onStateChanged);
    if (_ownsState) {
      _state.dispose();
    }
    super.dispose();
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
  }

  Kaffeekasse? get _kasse => _state.data;
  bool get _loading => _state.loading;
  String? get _error => _state.error;

  Future<void> _reload() => _state.reload();

  Future<void> _openPaySheet(CoffeePayment payment) async {
    final l = AppLocalizations.of(context)!;
    final paid = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => CoffeePaySheet(state: _state, payment: payment),
    );
    if (paid == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.kaffeekassePaid)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final maxW = AppLayout.contentMaxWidth(width);
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.kaffeekasseTitle)),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxW),
          child: _body(context),
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (_loading && _kasse == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final kasse = _kasse;
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(WachbuchTokens.space4),
        children: [
          if (_error != null) ...[
            ErrorBanner(message: _error!),
            const SizedBox(height: WachbuchTokens.space4),
          ],
          if (kasse != null) ...[
            if (kasse.hasMonthlyFee)
              _OwnStatusCard(own: kasse.own!)
            else
              _BalanceCard(kasse: kasse),
            const SizedBox(height: WachbuchTokens.space4),
            if (kasse.monthlyFee > 0 && kasse.own?.participant == false) ...[
              Text(
                AppLocalizations.of(context)!.kaffeekasseNotParticipant,
                style: TextStyle(color: WachbuchColors.of(context).muted),
              ),
              const SizedBox(height: WachbuchTokens.space4),
            ],
            if (kasse.hasMonthlyFee && kasse.own!.months.isNotEmpty) ...[
              _MonthsCard(months: kasse.own!.months),
              const SizedBox(height: WachbuchTokens.space4),
            ],
            if (kasse.payment != null) ...[
              FilledButton.icon(
                key: const Key('coffee-i-paid'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(WachbuchTokens.touchTarget),
                ),
                onPressed: () => _openPaySheet(kasse.payment!),
                icon: const Icon(Icons.check_circle_outline),
                label: Text(AppLocalizations.of(context)!.kaffeekasseIPaid),
              ),
              const SizedBox(height: WachbuchTokens.space4),
              if (kasse.payment!.iban.isNotEmpty ||
                  kasse.payment!.paypalUrl.isNotEmpty ||
                  kasse.payment!.weroUrl.isNotEmpty) ...[
                _TransferCard(payment: kasse.payment!),
                const SizedBox(height: WachbuchTokens.space4),
              ],
            ],
            if (kasse.paymentHint.isNotEmpty) ...[
              _PaymentHintCard(hint: kasse.paymentHint),
              const SizedBox(height: WachbuchTokens.space4),
            ],
            SectionTitle(
              icon: Icons.receipt_outlined,
              title: AppLocalizations.of(context)!.kaffeekasseLastTransactions,
            ),
            const SizedBox(height: WachbuchTokens.space2),
            if (kasse.ledger.isEmpty)
              EmptyState(
                icon: Icons.receipt_long_outlined,
                title: AppLocalizations.of(context)!.kaffeekasseEmptyLedgerTitle,
                message: AppLocalizations.of(context)!.kaffeekasseEmptyLedger,
                actionLabel: AppLocalizations.of(context)!.refreshTooltip,
                onAction: _reload,
              )
            else
              for (final entry in kasse.ledger) ...[
                _LedgerTile(entry: entry),
                const Divider(height: 1),
              ],
          ],
        ],
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.kasse});

  final Kaffeekasse kasse;

  @override
  Widget build(BuildContext context) {
    final c = WachbuchColors.of(context);
    final urgent = kasse.isNegative;
    final background = urgent ? c.dangerSoft : c.surface;
    final borderColor = urgent ? c.danger.withValues(alpha: 0.45) : c.line;
    final foreground = urgent ? c.danger : c.text;
    final iconColor = urgent ? c.danger : c.brand;
    return Material(
      color: background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(WachbuchTokens.radiusLg),
        side: BorderSide(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(WachbuchTokens.space5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.coffee_outlined,
                  color: iconColor,
                  size: 28,
                ),
                const SizedBox(width: WachbuchTokens.space3),
                Expanded(
                  child: Text(
                    switch (kasse.scope) {
                      'station' =>
                        AppLocalizations.of(context)!.kaffeekasseBalanceStation,
                      'own' => AppLocalizations.of(context)!.kaffeekasseBalanceOwn,
                      _ => AppLocalizations.of(context)!.kaffeekasseBalanceLabel,
                    },
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: foreground,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: WachbuchTokens.space3),
            Text(
              kasse.balance,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w700,
                    fontFeatures: WachbuchTokens.tabularFigures,
                  ),
            ),
            if (urgent) ...[
              const SizedBox(height: WachbuchTokens.space2),
              Text(
                AppLocalizations.of(context)!.kaffeekasseNegative,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: foreground,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PaymentHintCard extends StatelessWidget {
  const _PaymentHintCard({required this.hint});

  final String hint;

  @override
  Widget build(BuildContext context) {
    final c = WachbuchColors.of(context);
    return Material(
      color: c.surfaceSoft,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(WachbuchTokens.radiusMd),
        side: BorderSide(color: c.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(WachbuchTokens.space4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.payments_outlined,
              color: c.brand,
            ),
            const SizedBox(width: WachbuchTokens.space3),
            Expanded(
              child: Text(
                hint,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: c.text,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LedgerTile extends StatelessWidget {
  const _LedgerTile({required this.entry});

  final KaffeekasseEntry entry;

  @override
  Widget build(BuildContext context) {
    final c = WachbuchColors.of(context);
    final amountColor =
        entry.isNegative ? c.danger : c.brand;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: WachbuchTokens.space1),
      title: Text(
        entry.description.isNotEmpty
            ? entry.description
            : AppLocalizations.of(context)!.kaffeekasseEntryFallback,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: c.text),
      ),
      subtitle: Text(
        [
          if (entry.userName.isNotEmpty) entry.userName,
          if (entry.createdAt != null) _formatTimestamp(entry.createdAt!),
        ].join(' · '),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: c.muted,
              fontFeatures: WachbuchTokens.tabularFigures,
            ),
      ),
      trailing: Text(
        entry.formattedAmount,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: amountColor,
              fontWeight: FontWeight.w600,
              fontFeatures: WachbuchTokens.tabularFigures,
            ),
      ),
    );
  }
}

String _formatTimestamp(DateTime date) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(date.day)}.${two(date.month)}.${date.year}, '
      '${two(date.hour)}:${two(date.minute)} Uhr';
}

class _OwnStatusCard extends StatelessWidget {
  const _OwnStatusCard({required this.own});

  final CoffeeOwnStatus own;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final c = WachbuchColors.of(context);
    final open = own.openEuros > 0;
    final background = open ? c.dangerSoft : c.surface;
    final borderColor = open ? c.danger.withValues(alpha: 0.45) : c.line;
    final foreground = open ? c.danger : c.text;
    final iconColor = open ? c.danger : c.brand;
    final (label, value) = open
        ? (l.kaffeekasseOpen, own.formattedOpen)
        : own.creditEuros > 0
            ? (l.kaffeekasseCredit, own.formattedCredit)
            : (l.kaffeekasseMyStatus, l.kaffeekasseAllPaid);
    return Material(
      key: const Key('coffee-own-status'),
      color: background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(WachbuchTokens.radiusLg),
        side: BorderSide(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(WachbuchTokens.space5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.coffee_outlined, color: iconColor, size: 28),
                const SizedBox(width: WachbuchTokens.space3),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(color: foreground),
                  ),
                ),
              ],
            ),
            const SizedBox(height: WachbuchTokens.space3),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w700,
                    fontFeatures: WachbuchTokens.tabularFigures,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthsCard extends StatelessWidget {
  const _MonthsCard({required this.months});

  final List<CoffeeMonth> months;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final c = WachbuchColors.of(context);
    final material = MaterialLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          icon: Icons.calendar_month_outlined,
          title: l.kaffeekasseMonthsTitle,
        ),
        const SizedBox(height: WachbuchTokens.space2),
        Wrap(
          spacing: WachbuchTokens.space2,
          runSpacing: WachbuchTokens.space2,
          children: [
            for (final month in months)
              Chip(
                avatar: Icon(
                  switch (month.status) {
                    'paid' => Icons.check_circle,
                    'open' => Icons.schedule,
                    _ => Icons.beach_access_outlined,
                  },
                  size: 18,
                  color: month.status == 'open' ? c.danger : c.brand,
                ),
                label: Text(
                  '${month.month != null ? material.formatMonthYear(month.month!) : '?'} · '
                  '${switch (month.status) {
                    'paid' => l.kaffeekasseMonthPaid,
                    'open' => l.kaffeekasseMonthOpen(month.formattedOpen),
                    _ => l.kaffeekasseMonthWaived,
                  }}',
                  style: const TextStyle(
                    fontFeatures: WachbuchTokens.tabularFigures,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _TransferCard extends StatelessWidget {
  const _TransferCard({required this.payment});

  final CoffeePayment payment;

  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final c = WachbuchColors.of(context);
    final text = Theme.of(context).textTheme;
    Widget row(String label, String value, {bool copy = false}) => Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: text.labelMedium?.copyWith(color: c.muted)),
                  SelectableText(
                    value,
                    style: text.bodyLarge?.copyWith(
                      color: c.text,
                      fontFeatures: WachbuchTokens.tabularFigures,
                    ),
                  ),
                ],
              ),
            ),
            if (copy) CopyIconButton(text: value.replaceAll(' ', ''), label: label),
          ],
        );
    return Card(
      key: const Key('coffee-transfer'),
      color: c.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(WachbuchTokens.radiusLg),
        side: BorderSide(color: c.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(WachbuchTokens.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionTitle(
              icon: Icons.account_balance_outlined,
              title: l.kaffeekasseTransferTitle,
            ),
            const SizedBox(height: WachbuchTokens.space3),
            if (payment.iban.isNotEmpty) ...[
              row(l.kaffeekasseRecipient, payment.accountHolder),
              row(l.kaffeekasseIban, payment.formattedIban, copy: true),
              if (payment.suggestedEuros > 0)
                row(
                  l.kaffeekasseSuggested,
                  '${payment.suggestedEuros.toStringAsFixed(2).replaceAll('.', ',')} €',
                ),
              if (payment.transferText.isNotEmpty)
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l.kaffeekasseReference, style: text.labelMedium?.copyWith(color: c.muted)),
                          SelectableText(
                            payment.transferText,
                            style: text.bodyLarge?.copyWith(
                              color: c.text,
                              fontFeatures: WachbuchTokens.tabularFigures,
                            ),
                          ),
                        ],
                      ),
                    ),
                    CopyIconButton(text: payment.transferText, label: l.kaffeekasseReference),
                  ],
                ),
            ],
            if (payment.paypalUrl.isNotEmpty || payment.weroUrl.isNotEmpty) ...[
              const SizedBox(height: WachbuchTokens.space3),
              Wrap(
                spacing: WachbuchTokens.space2,
                runSpacing: WachbuchTokens.space2,
                children: [
                  if (payment.paypalUrl.isNotEmpty)
                    OutlinedButton.icon(
                      onPressed: () => _open(payment.paypalUrl),
                      icon: const Icon(Icons.open_in_new),
                      label: Text(l.kaffeekasseOpenPaypal),
                    ),
                  if (payment.weroUrl.isNotEmpty)
                    OutlinedButton.icon(
                      onPressed: () => _open(payment.weroUrl),
                      icon: const Icon(Icons.open_in_new),
                      label: Text(l.kaffeekasseOpenWero),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// „Ich habe bezahlt“ – wie das Kreuz in der Mappe.
class CoffeePaySheet extends StatefulWidget {
  const CoffeePaySheet({super.key, required this.state, required this.payment});

  final CoffeeState state;
  final CoffeePayment payment;

  @override
  State<CoffeePaySheet> createState() => _CoffeePaySheetState();
}

class _CoffeePaySheetState extends State<CoffeePaySheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amount;
  final _note = TextEditingController();
  late String _method;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _method = widget.payment.methods.first;
    final suggested = widget.payment.suggestedEuros;
    _amount = TextEditingController(
      text: suggested > 0 ? suggested.toStringAsFixed(2).replaceAll('.', ',') : '',
    );
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  num? _parsedAmount() => num.tryParse(_amount.text.trim().replaceAll(',', '.'));

  String _methodLabel(AppLocalizations l, String method) => switch (method) {
        'cash' => l.kaffeekasseMethodCash,
        'transfer' => l.kaffeekasseMethodTransfer,
        'paypal' => 'PayPal',
        'wero' => 'Wero',
        _ => method,
      };

  Future<void> _submit(AppLocalizations l) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.state.reportPayment(
        method: _method,
        amountEuros: _parsedAmount()!,
        note: _note.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = l.kaffeekassePayFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final c = WachbuchColors.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          WachbuchTokens.space5,
          0,
          WachbuchTokens.space5,
          WachbuchTokens.space5 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l.kaffeekasseIPaid,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: c.text,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: WachbuchTokens.space2),
              Text(
                l.kaffeekassePayHint,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: c.muted,
                    ),
              ),
              const SizedBox(height: WachbuchTokens.space4),
              Text(l.kaffeekassePayMethod, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: WachbuchTokens.space2),
              SegmentedButton<String>(
                key: const Key('coffee-pay-method'),
                segments: [
                  for (final method in widget.payment.methods)
                    ButtonSegment(value: method, label: Text(_methodLabel(l, method))),
                ],
                selected: {_method},
                onSelectionChanged: (selection) => setState(() => _method = selection.first),
              ),
              const SizedBox(height: WachbuchTokens.space4),
              TextFormField(
                key: const Key('coffee-pay-amount'),
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: l.kaffeekasseAmount, suffixText: '€'),
                validator: (_) {
                  final value = _parsedAmount();
                  return value == null || value < 0.01 || value > 500 ? l.kaffeekasseAmountInvalid : null;
                },
              ),
              const SizedBox(height: WachbuchTokens.space2),
              TextFormField(
                controller: _note,
                maxLength: 120,
                decoration: InputDecoration(labelText: l.kaffeekasseNote),
              ),
              if (_error != null) ...[
                const SizedBox(height: WachbuchTokens.space2),
                Text(_error!, style: TextStyle(color: c.danger)),
              ],
              const SizedBox(height: WachbuchTokens.space4),
              FilledButton.icon(
                key: const Key('coffee-pay-submit'),
                onPressed: _saving ? null : () => _submit(l),
                icon: _saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.check),
                label: Text(l.kaffeekassePaySubmit),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
