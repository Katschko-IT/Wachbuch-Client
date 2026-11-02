/// Kennzahlen aus `GET /api/v1/reports/`.
///
/// Bewusst ohne Zahlen je Person: `defects_by_owner` älterer Server (< 0.26.1)
/// wird weder gelesen noch gehalten (Produktgrenze: keine Leistungsdaten).
class WachalltagReport {
  const WachalltagReport({
    required this.openDefects,
    required this.overdueDefects,
    required this.overdueChecks,
    required this.assetsTotal,
    required this.assetsReady,
    required this.assetReadyPercent,
    required this.inventoryOut,
    required this.unacknowledgedActiveHandovers,
    required this.oldestOpenDays,
  });

  factory WachalltagReport.fromJson(Map<String, dynamic> json) {
    return WachalltagReport(
      openDefects: _readInt(json['open_defects']),
      overdueDefects: _readInt(json['overdue_defects']),
      overdueChecks: _readInt(json['overdue_checks']),
      assetsTotal: _readInt(json['assets_total']),
      assetsReady: _readInt(json['assets_ready']),
      assetReadyPercent: _readInt(json['asset_ready_percent']),
      inventoryOut: _readInt(json['inventory_out']),
      unacknowledgedActiveHandovers: _readInt(json['unacknowledged_active_handovers']),
      oldestOpenDays: _readInt(json['oldest_open_days']),
    );
  }

  final int openDefects;
  final int overdueDefects;
  final int overdueChecks;
  final int assetsTotal;
  final int assetsReady;
  final int assetReadyPercent;
  final int inventoryOut;
  final int unacknowledgedActiveHandovers;
  final int oldestOpenDays;
}

int _readInt(Object? value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
