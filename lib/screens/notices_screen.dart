import 'package:flutter/material.dart';
import 'package:wachbuch_mobile/api/client.dart';
import 'package:wachbuch_mobile/l10n/generated/app_localizations.dart';
import 'package:wachbuch_mobile/models/crew_notice.dart';
import 'package:wachbuch_mobile/screens/reading_obligations_screen.dart';
import 'package:wachbuch_mobile/theme/design_tokens.dart';
import 'package:wachbuch_mobile/ui/date_time_text.dart';
import 'package:wachbuch_mobile/ui/empty_state.dart';
import 'package:wachbuch_mobile/ui/error_banner.dart';
import 'package:wachbuch_mobile/ui/layout.dart';
import 'package:wachbuch_mobile/ui/server_page.dart';

/// Persönlicher Posteingang (`GET /api/v1/benachrichtigungen/?kinds=…`).
///
/// Zeigt nur die Arten, die die App kennt ([CrewNotice.shownKinds]), und
/// meldet genau die angezeigten ungelesenen Hinweise einzeln als gelesen.
/// Unbekannte Arten bleiben auf dem Server ungelesen.
class NoticesScreen extends StatefulWidget {
  const NoticesScreen({
    super.key,
    required this.api,
    this.openPage = openServerPageExternally,
  });

  final WachbuchApi api;
  final ServerPageOpener openPage;

  @override
  State<NoticesScreen> createState() => _NoticesScreenState();
}

class _NoticesScreenState extends State<NoticesScreen> {
  List<CrewNotice> _notices = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final notices = (await widget.api.crewNotices())
          .where((notice) => notice.isShownKind)
          .toList(growable: false);
      if (!mounted) return;
      setState(() {
        _notices = notices;
        _loading = false;
      });
      await _markShownRead(notices);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    }
  }

  Future<void> _markShownRead(List<CrewNotice> notices) async {
    for (final notice in notices) {
      if (notice.read || notice.id <= 0) continue;
      try {
        await widget.api.markCrewNoticeRead(notice.id);
      } on ApiException catch (error) {
        if (error.isSessionInvalid) rethrow;
      }
    }
  }

  Future<void> _open(CrewNotice notice) async {
    final l = AppLocalizations.of(context)!;
    if (notice.kind == CrewNotice.sopDue) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ReadingObligationsScreen(
            api: widget.api,
            openPage: widget.openPage,
          ),
        ),
      );
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final uri = widget.api.webPage(notice.url);
    final opened = uri != null && await widget.openPage(uri);
    if (!opened) {
      messenger.showSnackBar(SnackBar(content: Text(l.sopOpenFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final width = MediaQuery.sizeOf(context).width;
    return Scaffold(
      appBar: AppBar(title: Text(l.noticesTitle)),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: AppLayout.contentMaxWidth(width),
          ),
          child: RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  l.noticesHint,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: WachbuchColors.of(context).muted,
                  ),
                ),
                const SizedBox(height: 12),
                if (_error != null) ...[
                  ErrorBanner(message: _error!),
                  const SizedBox(height: 12),
                ],
                if (_loading && _notices.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_notices.isEmpty)
                  EmptyState(
                    icon: Icons.notifications_none,
                    title: l.noticesTitle,
                    message: l.noticesEmpty,
                    actionLabel: l.refreshTooltip,
                    onAction: _reload,
                  )
                else
                  for (final notice in _notices)
                    _NoticeTile(
                      notice: notice,
                      onTap:
                          notice.kind == CrewNotice.sopDue ||
                              widget.api.webPage(notice.url) != null
                          ? () => _open(notice)
                          : null,
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bezeichnung und Symbol je Art.
(String, IconData) noticeKindLabel(AppLocalizations l, CrewNotice notice) {
  if (notice.isWeeklyDigest) {
    return (l.noticeKindDigest, Icons.view_week_outlined);
  }
  return switch (notice.kind) {
    CrewNotice.vehicleReady => (
      l.noticeKindVehicleReady,
      Icons.local_shipping_outlined,
    ),
    CrewNotice.coffeeDue => (l.noticeKindCoffeeDue, Icons.coffee_outlined),
    CrewNotice.deadlineDue => (l.noticeKindDeadline, Icons.event_busy_outlined),
    CrewNotice.sopDue => (l.noticeKindSop, Icons.menu_book_outlined),
    CrewNotice.mpgTrainingMissing => (
      l.noticeKindMpgTraining,
      Icons.school_outlined,
    ),
    CrewNotice.systemHealth => (l.noticeKindSystemHealth, Icons.dns_outlined),
    _ => (notice.kind, Icons.notifications_outlined),
  };
}

class _NoticeTile extends StatelessWidget {
  const _NoticeTile({required this.notice, required this.onTap});

  final CrewNotice notice;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final c = WachbuchColors.of(context);
    final (label, icon) = noticeKindLabel(l, notice);
    final created = notice.createdAt;
    return Card(
      key: Key('notice-${notice.id}'),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: c.brandDeep),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          label,
                          style: Theme.of(
                            context,
                          ).textTheme.labelLarge?.copyWith(color: c.muted),
                        ),
                        if (!notice.read)
                          Text(
                            l.noticeUnread,
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  color: c.brandDeep,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notice.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (notice.body.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(notice.body),
                    ],
                    if (created != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        formatDateTimeShort(context, created),
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: c.muted),
                      ),
                    ],
                  ],
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 8),
                Tooltip(
                  message: notice.kind == CrewNotice.sopDue
                      ? l.sopScreenTitle
                      : l.noticeOpenInBrowser,
                  child: Icon(Icons.chevron_right, color: c.muted),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
