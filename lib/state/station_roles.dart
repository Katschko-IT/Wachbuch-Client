/// Rollenrechte wie serverseitig festgelegt.
///
/// Quelle: `core/api/views.py` (`WRITE_ROLES`) und `core/access.py`
/// (`CONTENT_ROLES`) im Server-Repository. Die App blendet damit nur Aktionen
/// aus; die verbindliche Prüfung bleibt beim Server.
library;

class StationRoles {
  StationRoles._();

  /// `WRITE_ROLES = {SHIFT_LEAD, ADMIN}`
  static const writeRoles = {'shift_lead', 'admin'};

  /// `CONTENT_ROLES = {MEMBER, SHIFT_LEAD, CASHIER, ADMIN}` (ohne Auditor).
  static const contentRoles = {'member', 'shift_lead', 'cashier', 'admin'};

  static bool hasWriteRole(String? role) => writeRoles.contains(role);

  /// POST /api/v1/handovers/ verlangt eine Inhaltsrolle.
  static bool canCreateHandover(String? role) => contentRoles.contains(role);

  /// POST /api/v1/handovers/{id}/status/ verlangt `WRITE_ROLES`.
  static bool canChangeHandoverStatus(String? role) => hasWriteRole(role);

  /// POST /api/v1/kalender/ verlangt `WRITE_ROLES`
  /// (`core/api/views.py`, `calendar_api`).
  static bool canCreateCalendarEntry(String? role) => hasWriteRole(role);

  /// POST /api/v1/assets/{id}/status/ verlangt `WRITE_ROLES`.
  static bool canChangeAssetStatus(String? role) => hasWriteRole(role);

  /// PATCH /api/v1/defects/{id}/ verlangt eine Inhaltsrolle
  /// (`core/api/wachalltag.py`, `defect_detail` mit `_content_role`).
  static bool canEditDefect(String? role) => contentRoles.contains(role);

  /// Mangel auf „erledigt“ setzen verlangt `WRITE_ROLES`.
  static bool canCloseDefect(String? role) => hasWriteRole(role);

  /// Rückgabe: frei, eigene Ausleihe oder `WRITE_ROLES` für fremde.
  static bool canCheckin({
    required String? role,
    required String? holder,
    required String? username,
  }) {
    if (holder == null || holder.isEmpty) return true;
    if (username != null && holder == username) return true;
    return hasWriteRole(role);
  }
}
