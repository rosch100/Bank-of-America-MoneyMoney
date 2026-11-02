# Bank of America — MoneyMoney-Erweiterung

Konten und Umsätze von Bank of America in MoneyMoney.

Version: **0.93** (Beta)
Repository: https://github.com/rosch100/Bank-of-America-MoneyMoney
Gemeinsame Infos: https://github.com/rosch100/moneymoney-extensions

## Installation

Datei (inkl. MoneyMoney Signatur, wie auf moneymoney-app.com):
[Bank of America.lua](https://raw.githubusercontent.com/rosch100/Bank-of-America-MoneyMoney/main/Bank%20of%20America.lua)

Nutzt `MM.base64` / `MM.base64decode`. Datei nach
`~/Library/Containers/com.moneymoney-app.retail/Data/Library/Application Support/MoneyMoney/Extensions`
kopieren, oder im Klon `./link_ext.sh` ausführen.

Entwicklungs-Plugins ohne gültige Signatur: MoneyMoney-**Beta**, Signaturprüfung unter
*MoneyMoney → Einstellungen → Erweiterungen* ausschalten.

## Einrichten

*Konto hinzufügen* → *Andere* → **Bank of America**.

Anmeldung derzeit vor allem per Cookie-Import: Im Browser einloggen, Cookies mit
dem MoneyMoney Helper kopieren und als Passwort einfügen (`COOKIE:…`).
Schritt-für-Schritt: [Hub — Cookie-Import](https://github.com/rosch100/moneymoney-extensions#cookie-import-beta-extensions).

## Nutzung

Nach dem Einrichten den Zugang in MoneyMoney aktualisieren. Läuft die Session ab,
Cookies erneut kopieren und das Passwortfeld aktualisieren.

## Bekannte Einschränkungen

Stand: 2. November 2026

- **Kein Passwort-Login.** Die Anmeldeseite verlangt Daten aus dem JavaScript der Seite
  (Anti-Fraud: BioCatch, ThreatMetrix, Script-Hashes). Diese lassen sich mit reinem HTTP nicht
  nachbilden. Für einen Direct-Login fehlt außerdem die Engine-API `WebbankingBrowser` in MoneyMoney
  ([Details](https://github.com/rosch100/moneymoney-extensions/blob/main/docs/ENGINE-API-GAPS.md)).
  Die Anmeldung läuft deshalb nur über Cookies. Der frühere Passwort-Login-Pfad wurde entfernt.
- **Kurze Sitzungsdauer.** Die BoA-Seite beendet eine Sitzung nach etwa 10 Minuten ohne Aktivität.
  Die Warnung „Your session is about to time out“ erscheint etwa 8 Minuten nach der letzten Aktivität.
  Die 10 Minuten stammen aus der Einstellung `timeoutInterval` der gespeicherten BoA-Seite
  (`warnRatio` 0.8). Im Browser wurde eine Restzeit von 1 Min. 46 Sek. beobachtet.
- **Cookies veralten schnell.** Ein Cookie-Import, der Tage alt ist, ist in aller Regel abgelaufen.
  Die Cookies deshalb kurz vor dem Abruf kopieren und ins Passwortfeld einfügen.
  Die Extension speichert Import-Cookies nicht dauerhaft.
- **Abgelaufene Sitzung.** Meldet BoA die Sitzung als abgelaufen, bricht der Abruf mit dem Hinweis
  ab, neue Cookies als `COOKIE:…` ins Passwortfeld einzutragen. Die Extension verwendet dafür bewusst
  kein `LoginFailed`: Laut Kommentar im Amazon-Projekt löscht es Cookies und erzwingt eine erneute
  Passwort-Abfrage.
- **Verbindung mit Cookie-Jar bleibt gespeichert.** Das Verbindungsobjekt liegt in `LocalStorage` und
  wird beim nächsten Abruf wiederverwendet. Vermutlich braucht die Extension das, damit Cookies
  zwischen Anmeldung und Kontoabruf erhalten bleiben. Das ist nicht per Test belegt. Der Jar enthält
  damit Sitzungs-Cookies, die über den Abruf hinaus gespeichert sind. Diese sind nach etwa
  10 Minuten ohne Aktivität ungültig.

Live-Test am 2. November 2026: Ein Abruf mit gespeicherter Sitzung war erfolgreich (3 Umsätze).

## Fehler & Ideen

Issues bitte über GitHub melden:
[Neues Issue](https://github.com/rosch100/Bank-of-America-MoneyMoney/issues/new/choose).
Keine MoneyMoney-Logdateien anhängen — Details stehen im Bug-Formular.

## Lizenz

MIT — siehe [LICENSE](LICENSE).
