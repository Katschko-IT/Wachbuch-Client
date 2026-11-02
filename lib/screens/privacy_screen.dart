import 'package:flutter/material.dart';
import 'package:wachbuch_mobile/theme/design_tokens.dart';
import 'package:url_launcher/link.dart';

const _privacyPolicyUri =
    'https://github.com/Katschko-IT/Wachbuch-Client/'
    'blob/main/docs/PRIVACY-POLICY.md';
const _supportUri =
    'https://github.com/Katschko-IT/Wachbuch-Client/'
    'blob/main/docs/SUPPORT.md';

/// Store-facing privacy information that remains reachable before login.
///
/// The canonical, versioned policy lives in docs/PRIVACY-POLICY.md. This
/// screen intentionally contains the operational essentials and a real public
/// privacy-policy link so the store disclosure does not depend on a WebView.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final german = Localizations.localeOf(context).languageCode == 'de';
    final policy = german ? _de : _en;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(policy.title)),
      body: SafeArea(
        child: SelectionArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              Text(
                policy.intro,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 20),
              for (final section in policy.sections) ...[
                Text(
                  section.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(section.body),
                const SizedBox(height: 18),
              ],
              Material(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(WachbuchTokens.radiusMd),
                child: Padding(
                  padding: const EdgeInsets.all(WachbuchTokens.space4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        policy.canonicalTitle,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const SelectableText(_privacyPolicyUri),
                      const SizedBox(height: 8),
                      Link(
                        uri: Uri.parse(_privacyPolicyUri),
                        target: LinkTarget.blank,
                        builder: (context, followLink) => OutlinedButton.icon(
                          key: const Key('open-privacy-policy'),
                          onPressed: followLink,
                          icon: const Icon(Icons.open_in_new),
                          label: Text(policy.openPolicy),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        policy.supportTitle,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const SelectableText(_supportUri),
                      const SizedBox(height: 8),
                      Link(
                        uri: Uri.parse(_supportUri),
                        target: LinkTarget.blank,
                        builder: (context, followLink) => TextButton.icon(
                          key: const Key('open-support-page'),
                          onPressed: followLink,
                          icon: const Icon(Icons.support_agent_outlined),
                          label: Text(policy.openSupport),
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
}

class _PolicyCopy {
  const _PolicyCopy({
    required this.title,
    required this.intro,
    required this.sections,
    required this.canonicalTitle,
    required this.supportTitle,
    required this.openPolicy,
    required this.openSupport,
  });

  final String title;
  final String intro;
  final List<_PolicySection> sections;
  final String canonicalTitle;
  final String supportTitle;
  final String openPolicy;
  final String openSupport;
}

class _PolicySection {
  const _PolicySection(this.title, this.body);

  final String title;
  final String body;
}

const _de = _PolicyCopy(
  title: 'Datenschutz',
  intro:
      'Wachwerk ist ein Open-Source-Client für selbst gehostete '
      'Wachwerk-Server. Die App betreibt keine zentrale Wachwerk-Cloud und ist '
      'keine offizielle Behörden-, Notruf-, Einsatzleit-, Patientenakten- oder '
      'ePCR-App.',
  sections: [
    _PolicySection(
      'Lokale Daten',
      'Die App speichert die ausgewählte Serveradresse lokal. App-Token und '
          'der Offline-Lesecache werden über den sicheren Speicher des '
          'Betriebssystems geschützt. Der Offline-Lesecache enthält nur die '
          'eigene Mitgliedschaft, Checklisten und die Übergabeliste ohne '
          'Freitext, höchstens 24 Stunden lang. Für Master-Admin, Kassenwart '
          'und Auditor gibt es keinen Offline-Cache. Gelesen wird er erst, '
          'nachdem die Sitzung online bestätigt wurde; ein Kaltstart ohne Netz '
          'zeigt keine Wachendaten.',
    ),
    _PolicySection(
      'Abmelden und ungültige Sitzung',
      'Beim Abmelden oder Serverwechsel entfernt die App Token und '
          'Offline-Cache und sperrt den entschlüsselten Schlüssel für '
          'Nachrichten. Erkennt der Server die Sitzung nicht mehr an (abgelaufen, '
          'widerrufen oder kein aktiver Wachenzugang), meldet die App ebenso ab.',
    ),
    _PolicySection(
      'Verbindung zum selbst gehosteten Server',
      'Anmeldung und Organisationsdaten wie Übergaben, Checklisten, Mängel, '
          'Geräte-/Fahrzeugstatus und Inventar werden nur an den Server '
          'übertragen, den Sie selbst eingerichtet haben. Das gilt auch für '
          'neu angelegte Übergaben und Termine, Änderungen an Mängeln, die '
          'Meldung „Ich habe bezahlt“ der Kaffeekasse (Betrag, Zahlungsweg, '
          'Notiz) und den Gelesen-Status persönlicher Hinweise. Ein Passwort '
          'für den Token-Austausch wird von der App nicht dauerhaft '
          'gespeichert.',
    ),
    _PolicySection(
      'Benachrichtigungen',
      'Mit Ihrer Erlaubnis plant die App lokale Benachrichtigungen, zum '
          'Beispiel wenn ein Fahrzeug nach der Desinfektion freigegeben werden '
          'kann, und zeigt bekannte persönliche Hinweise Ihres Servers an. '
          'Dafür werden keine Daten an den App-Entwickler oder an Dritte '
          'übertragen.',
    ),
    _PolicySection(
      'Kamera und Fotos',
      'Beim QR-Scan werden Kameraframes nur zur Erkennung der Serveradresse '
          'verarbeitet und nicht als Foto hochgeladen. Ein Mängelfoto wird nur '
          'übertragen, wenn Sie es ausdrücklich aufnehmen oder aus der '
          'Fotomediathek auswählen. Patienten- oder Einsatzdaten gehören nicht '
          'in Mängelfotos.',
    ),
    _PolicySection(
      'Standort',
      'Ein optionaler ungefährer Standort wird ausschließlich lokal zur '
          'Berechnung von Sonnenaufgang und Sonnenuntergang für das '
          'Tag-/Nacht-Design verwendet und nach aktuellem App-Konzept nicht '
          'übertragen.',
    ),
    _PolicySection(
      'Werbung und Tracking',
      'Die App enthält keine Werbung, kein Werbe-SDK, kein Cross-App-Tracking '
          'und kein externes Analytics-/Crash-Tracking-SDK.',
    ),
    _PolicySection(
      'Konten und Löschung',
      'Benutzerkonten und serverseitige Daten werden vom Betreiber des '
          'verbundenen Wachwerk-Servers verwaltet. Auskunfts-, Berichtigungs- '
          'oder Löschanfragen zu diesen Daten sind an diesen Betreiber zu '
          'richten.',
    ),
  ],
  canonicalTitle: 'Vollständige Datenschutzerklärung',
  supportTitle: 'Support / Kontakt zur App',
  openPolicy: 'Datenschutzerklärung öffnen',
  openSupport: 'Support-Seite öffnen',
);

const _en = _PolicyCopy(
  title: 'Privacy',
  intro:
      'Wachwerk is an open-source client for self-hosted Wachwerk servers. '
      'The app does not operate a central Wachwerk cloud and is not an official '
      'government, emergency-calling, dispatch, patient-record or ePCR app.',
  sections: [
    _PolicySection(
      'Local data',
      'The selected server address is stored locally. App tokens and the '
          'offline read cache are protected using operating system secure '
          'storage. The offline read cache holds only your own membership, '
          'checklists and the handover list without free text, for at most '
          '24 hours. There is no offline cache for master admins, treasurers '
          'and auditors. It is read only after the session has been confirmed '
          'online; a cold start without network shows no station data.',
    ),
    _PolicySection(
      'Signing out and invalid sessions',
      'Signing out or changing servers removes the token and offline cache '
          'and locks the decrypted key for messages. If the server no longer '
          'accepts the session (expired, revoked or no active station access), '
          'the app signs out as well.',
    ),
    _PolicySection(
      'Self-hosted server connection',
      'Authentication and organisational data such as handovers, checklists, '
          'defects, asset/vehicle status and inventory are sent only to the '
          'server you configured. This includes newly created handovers and '
          'calendar entries, defect edits, the coffee fund "I have paid" report '
          '(amount, payment method, note) and the read status of personal '
          'notices. A password used for token exchange is not persistently '
          'stored by the app.',
    ),
    _PolicySection(
      'Notifications',
      'With your permission the app schedules local notifications, for '
          'example when a vehicle can be released after disinfection, and '
          'shows known personal notices from your server. No data is sent to '
          'the app developer or third parties for this.',
    ),
    _PolicySection(
      'Camera and photos',
      'QR camera frames are processed only to recognise the server address and '
          'are not uploaded as photos. A defect photo is transmitted only when '
          'you explicitly capture or select one. Patient or incident data '
          'should never be included in defect photos.',
    ),
    _PolicySection(
      'Location',
      'Optional approximate location is used locally only to calculate sunrise '
          'and sunset for the day/night theme and is not transmitted under the '
          'current app design.',
    ),
    _PolicySection(
      'Advertising and tracking',
      'The app contains no advertising, advertising SDK, cross-app tracking '
          'or external analytics/crash-tracking SDK.',
    ),
    _PolicySection(
      'Accounts and deletion',
      'User accounts and server-side data are managed by the operator of the '
          'Wachwerk server you connect to. Requests to access, correct or '
          'delete that data must be directed to that server operator.',
    ),
  ],
  canonicalTitle: 'Full privacy policy',
  supportTitle: 'App support / contact',
  openPolicy: 'Open privacy policy',
  openSupport: 'Open support page',
);
