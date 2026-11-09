#!/usr/bin/env python3
"""Erzeugt die API-Vertragsfixtures der App aus dem echten Wachwerk-Server.

Das Skript startet den Server-Code im Testmodus (eigene, leere SQLite-
Testdatenbank, eingefrorene Uhr), legt eine kleine Musterwache an und ruft
die Endpunkte, die die App nutzt, über den Django-Testclient auf. Die
Antworten landen unverändert (bis auf Korrelations-IDs) als JSON unter
``test/fixtures/server-<version>/``; ``test/api_contract_fixtures_test.dart``
liest sie mit den echten Modellen der App. Benennt der Server ein Feld um,
schlägt der Test fehl.

Aufruf (siehe docs/API-VERTRAG-FIXTURES.md):

    export PATH=/pfad/zum/server-venv/bin:$PATH
    export DJANGO_SECRET_KEY=ci-only-secret DJANGO_DEBUG=false \\
        REDIS_URL= REDIS_HOST= DATABASE_URL=
    python tool/server_contract/generate_fixtures.py --server ../Rettungswache-Wachbuch

Keine Patienten-, Einsatz-, Alarmierungs- oder Gesundheitsdaten: Die
Musterwache enthält nur Wachalltag (Übergaben, Mängel, Checklisten,
Dienstanweisungen, Hinweise) mit erfundenen Namen.
"""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from datetime import date, datetime, timedelta, timezone as dt_timezone
from decimal import Decimal
from pathlib import Path
from unittest import mock

FROZEN_NOW = datetime(2026, 11, 9, 7, 0, tzinfo=dt_timezone.utc)
CLIENT_ROOT = Path(__file__).resolve().parents[2]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--server", required=True, help="Pfad zum Server-Repository (Wachwerk)")
    parser.add_argument(
        "--api",
        default="0.28",
        help="API-Stand, für den die App gebaut ist (Ordnername, Standard: 0.28)",
    )
    parser.add_argument(
        "--out",
        default=None,
        help="Zielordner (Standard: test/fixtures/server-<api>)",
    )
    return parser.parse_args()


def server_commit(server: Path) -> str:
    try:
        return subprocess.run(
            ["git", "-C", str(server), "rev-parse", "--short", "HEAD"],
            check=True, capture_output=True, text=True,
        ).stdout.strip()
    except (OSError, subprocess.CalledProcessError):
        return "unbekannt"


def main() -> int:
    args = parse_args()
    server = Path(args.server).resolve()
    if not (server / "manage.py").exists():
        print(f"Kein Wachwerk-Server unter {server}", file=sys.stderr)
        return 2
    os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.test_settings")
    os.environ.setdefault("DJANGO_SECRET_KEY", "ci-only-secret")
    os.environ.setdefault("DJANGO_DEBUG", "false")
    for name in ("REDIS_URL", "REDIS_HOST", "DATABASE_URL"):
        os.environ.setdefault(name, "")
    sys.path.insert(0, str(server))
    os.chdir(server)

    import django

    django.setup()

    from django.test.runner import DiscoverRunner
    from django.test.utils import setup_test_environment, teardown_test_environment

    setup_test_environment()
    runner = DiscoverRunner(verbosity=0, interactive=False)
    old_config = runner.setup_databases()
    try:
        with mock.patch("django.utils.timezone.now", return_value=FROZEN_NOW):
            fixtures, version = collect()
    finally:
        runner.teardown_databases(old_config)
        teardown_test_environment()

    # Der Ordner heißt nach dem API-Stand der App, nicht nach der
    # Versionsnummer des Servers: Ein Server-Checkout kann die Funktionen von
    # 0.28 schon enthalten, bevor seine Versionsnummer angehoben ist. Die
    # tatsächliche Version und der Commit stehen im Manifest.
    out = Path(args.out) if args.out else CLIENT_ROOT / "test" / "fixtures" / f"server-{args.api}"
    out.mkdir(parents=True, exist_ok=True)
    for old in out.glob("*.json"):
        old.unlink()
    for name, payload in fixtures.items():
        (out / f"{name}.json").write_text(
            json.dumps(payload, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8",
        )
    manifest = {
        "api": args.api,
        "server_version": version,
        "server_commit": server_commit(server),
        "frozen_now": FROZEN_NOW.isoformat(),
        "generator": "tool/server_contract/generate_fixtures.py",
        "fixtures": sorted(fixtures),
    }
    (out / "_manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8",
    )
    print(f"{len(fixtures)} Fixtures nach {out.relative_to(CLIENT_ROOT)} geschrieben (Server {version}).")
    return 0


def normalize(value):
    """Korrelations-IDs sind je Anfrage zufällig; alles andere bleibt wie geliefert."""
    if isinstance(value, dict):
        return {
            key: ("correlation-id" if key == "correlation_id" and item else normalize(item))
            for key, item in value.items()
        }
    if isinstance(value, list):
        return [normalize(item) for item in value]
    return value


def collect():
    from django.contrib.auth import get_user_model
    from django.test import Client

    from core.api.views import DEFAULT_MOBILE_SCOPES, hash_api_token
    from core.models import ApiToken, Checklist, ChecklistItem, Membership, Station
    from core.notification_models import UserNotification
    from core.orga_models import SOPDocument, SOPRevision
    from core.version import APP_VERSION
    from core.wachalltag_models import Defect, StationAsset

    User = get_user_model()
    client = Client()
    fixtures: dict[str, object] = {}

    station = Station.objects.create(
        name="Rettungswache Musterstadt", slug="rw-muster", checklists_enabled=True, orga_enabled=True,
    )
    # Fremde Wache zuerst: Kennungen der eigenen Prüfpunkte beginnen nicht bei 1.
    other = Station.objects.create(name="Wache Süd", slug="rw-sued", checklists_enabled=True)
    foreign = Checklist.objects.create(station=other, title="Fremde Liste")
    for index in range(3):
        ChecklistItem.objects.create(checklist=foreign, text=f"Fremder Punkt {index}", position=index)

    member = User.objects.create_user("app.mitglied", first_name="Alex", last_name="Muster")
    lead = User.objects.create_user("app.schicht", first_name="Kim", last_name="Leitung")
    Membership.objects.create(user=member, station=station, role=Membership.Role.MEMBER)
    Membership.objects.create(user=lead, station=station, role=Membership.Role.SHIFT_LEAD)

    def token(user, raw):
        ApiToken.objects.create(
            user=user, label="Mobile App", token_prefix=raw[:11], token_hash=hash_api_token(raw),
            scopes=list(DEFAULT_MOBILE_SCOPES), expires_at=FROZEN_NOW + timedelta(days=90),
        )
        return {"HTTP_AUTHORIZATION": f"Token {raw}"}

    auth = token(member, "wb_contract_member_aaaaaaaaaaaaaaaaaaaa")
    lead_auth = token(lead, "wb_contract_lead_bbbbbbbbbbbbbbbbbbbbbb")

    def record(name, response, expected):
        assert response.status_code == expected, (name, response.status_code, response.content[:500])
        fixtures[name] = {"status": response.status_code, "body": normalize(response.json())}
        return response.json()

    def get(name, path, expected=200, headers=auth):
        return record(name, client.get(path, **headers), expected)

    def send(name, method, path, payload, expected, headers=auth):
        call = getattr(client, method)
        return record(name, call(path, data=json.dumps(payload), content_type="application/json", **headers), expected)

    # --- Discovery und eigene Mitgliedschaft --------------------------------
    get("discovery", "/api/v1/", headers={})
    get("me", "/api/v1/me/")

    # --- Übergaben: normal und Nachtrag vom Papierbogen ---------------------
    send("handover_create", "post", "/api/v1/handovers/", {
        "title": "Trage RTW 1 klemmt", "details": "Bitte prüfen.", "category": "vehicle", "priority": "urgent",
    }, 201)
    backfill = send("handover_create_backfill", "post", "/api/v1/handovers/", {
        "title": "Desinfektion RTW 1 vom Papierbogen", "details": "Nachtrag aus dem Nachtdienst.",
        "category": "vehicle", "priority": "normal", "is_paper_backfill": True,
        "occurred_at": (FROZEN_NOW - timedelta(hours=9, minutes=30)).isoformat(),
    }, 201)
    get("handovers", "/api/v1/handovers/")
    get("handover_detail_backfill", f"/api/v1/handovers/{backfill['id']}/")

    # --- Geräte & Fahrzeuge, Mängel, Hinweis „bereits gemeldet“ -------------
    StationAsset.objects.create(station=station, asset_id="rtw-1", label="RTW 1", kind="vehicle", updated_by=lead)
    StationAsset.objects.create(station=station, asset_id="rtw-10", label="RTW 10", kind="vehicle", updated_by=lead)
    StationAsset.objects.create(station=station, asset_id="defi-2", label="Defi 2", kind="device", updated_by=lead)
    get("assets", "/api/v1/assets/")
    send("defect_create", "post", "/api/v1/defects/", {
        "title": "Fahrzeug: RTW 1", "description": "Trage rastet nicht ein.", "asset_ref": "RTW 1",
        "priority": "important", "category": "vehicle",
    }, 201)
    Defect.objects.create(station=station, title="Blaulicht RTW 10", asset_ref="RTW 10", created_by=lead)
    get("defects_active", "/api/v1/defects/?active=1&limit=100")
    get("defects_for_reference", "/api/v1/defects/?active=1&asset=rtw-1&limit=5")

    # --- Checklisten mit Ergebnis je Prüfpunkt ------------------------------
    checklist = Checklist.objects.create(
        station=station, title="Kühlschrank- & Geräteprüfung", description="Morgendlicher Rundgang",
        requires_personal_login=True,
    )
    temp = ChecklistItem.objects.create(
        checklist=checklist, text="Medikamentenkühlschrank Temperatur", position=1, is_required=True,
        measurement_unit="°C", min_value=Decimal("2.00"), max_value=Decimal("8.00"),
    )
    seal = ChecklistItem.objects.create(checklist=checklist, text="Notfallrucksack Plombe intakt", position=2,
                                        is_required=True)
    heat = ChecklistItem.objects.create(checklist=checklist, text="Zusatzheizung Messwert", position=3,
                                        measurement_unit="°C", min_value=Decimal("0.00"))
    path = f"/api/v1/checklisten/{checklist.pk}"
    send("checklist_draft_put", "put", f"{path}/zwischenstand/", {
        "item_results": {
            str(temp.pk): {"status": "ok", "value": "5,2", "reason": ""},
            str(seal.pk): {"status": "na", "value": None, "reason": "Rucksack in der Werkstatt"},
        },
        "note": "Heizung noch offen",
    }, 200)
    get("checklists", "/api/v1/checklisten/")
    get("checklist_draft", f"{path}/zwischenstand/")
    send("checklist_run_invalid", "post", f"{path}/abschluss/", {
        "item_results": {
            str(temp.pk): {"status": "ok", "value": None, "reason": ""},
            str(heat.pk): {"status": "na", "value": None, "reason": ""},
        },
    }, 400)
    send("checklist_run", "post", f"{path}/abschluss/", {
        "item_results": {
            str(temp.pk): {"status": "ok", "value": "9,5", "reason": ""},
            str(seal.pk): {"status": "ok", "value": None, "reason": ""},
            str(heat.pk): {"status": "na", "value": None, "reason": "Sommerbetrieb"},
        },
        "note": "",
    }, 201)
    get("checklists_after_run", "/api/v1/checklisten/")

    # --- Lesepflicht --------------------------------------------------------
    sop = SOPDocument.objects.create(
        station=station, slug="da-hygiene", doc_number="DA-HYG-1", title="Händedesinfektion",
        status=SOPDocument.Status.ACTIVE, requires_acknowledgment=True,
        ack_due_date=date(2026, 11, 1), created_by=lead,
    )
    first = SOPRevision.objects.create(sop=sop, version_label="1.0", content_markdown="Text", approved_by=lead)
    SOPRevision.objects.create(sop=sop, version_label="1.1", content_markdown="Neu", approved_by=lead)
    later = SOPDocument.objects.create(
        station=station, slug="da-funk", doc_number="DA-FUNK-2", title="Funkdisziplin",
        status=SOPDocument.Status.ACTIVE, requires_acknowledgment=True,
        ack_due_date=date(2026, 12, 1), created_by=lead,
    )
    SOPRevision.objects.create(sop=later, version_label="2.0", content_markdown="Text", approved_by=lead)
    get("sops_open", "/api/v1/dienstanweisungen/?offen=1")
    send("sop_ack_stale_revision", "post", f"/api/v1/dienstanweisungen/{sop.pk}/quittieren/",
         {"revision": first.pk}, 409)
    send("sop_ack", "post", f"/api/v1/dienstanweisungen/{sop.pk}/quittieren/",
         {"revision": sop.latest_revision.pk}, 201)
    get("sops_all", "/api/v1/dienstanweisungen/")

    # --- Hinweise aller Arten von 0.28 --------------------------------------
    notices = [
        (UserNotification.Kind.VEHICLE_READY, "vehicle_ready:1:20261109", "RTW 1: Einwirkzeit abgelaufen",
         "Bitte Fahrzeug prüfen und den Status selbst freigeben.", ""),
        (UserNotification.Kind.COFFEE_DUE, "coffee_due:2026-11", "Kaffeekasse: Beitrag offen",
         "November ist noch offen.", "/kaffeekasse/"),
        (UserNotification.Kind.DEADLINE_DUE, "deadline:stk:1:7:2026-11-16", "Frist in 7 Tagen: STK RTW 1",
         "Bitte Termin vereinbaren.", "/fuhrpark/"),
        (UserNotification.Kind.DEADLINE_DUE, f"deadline_weekly_digest:{station.pk}:2026-W46",
         "Wochenübersicht KW 46: 2 Fristen", "STK RTW 1 · Lesefrist DA-FUNK-2", "/papier/fristen/"),
        (UserNotification.Kind.SOP_DUE, f"deadline:sop:{later.pk}:7:{member.pk}:7:2026-12-01",
         "Lesefrist Dienstanweisung DA-FUNK-2", "Bitte bestätigen.", f"/orga/sop/{later.slug}/"),
        (UserNotification.Kind.MPG_TRAINING_MISSING, "mpg_training:2", "MPG: Fehlende Einweisung",
         "Defi 2", "/mpg/"),
    ]
    for kind, key, title, body, url in notices:
        UserNotification.objects.create(
            station=station, user=member, kind=kind, dedupe_key=key, title=title, body=body, url=url,
        )
    kinds = "vehicle_ready,coffee_due,system_health,mpg_training_missing,deadline_due,sop_due"
    get("notifications", f"/api/v1/benachrichtigungen/?kinds={kinds}")
    first_notice = UserNotification.objects.filter(user=member).order_by("pk").first()
    send("notification_read", "post", f"/api/v1/benachrichtigungen/{first_notice.pk}/gelesen/", {}, 200)
    get("vehicle_locks", "/api/v1/fahrzeuge/sperren/")

    # --- Fehlervertrag ------------------------------------------------------
    get("error_unauthorized", "/api/v1/me/", expected=401,
        headers={"HTTP_AUTHORIZATION": "Token wb_contract_unknown_cccccccccccccccc"})
    send("error_defect_validation", "post", "/api/v1/defects/", {"title": ""}, 422)
    del lead_auth
    return fixtures, APP_VERSION


if __name__ == "__main__":
    sys.exit(main())
