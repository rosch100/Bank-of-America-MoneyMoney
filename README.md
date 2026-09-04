# Bank of America — MoneyMoney Extension
Plugin Homepage: https://github.com/rosch100/Bank-of-America-MoneyMoney
Bank/Portal: https://www.bankofamerica.com
Version: **0.91**
Status: Beta — Cookie-Import (Username/Passwort + MFA wenn Engine-API da)
Hub (gemeinsame Tools/Doku): https://github.com/rosch100/moneymoney-extensions
Optional Cookie-Import: Passwort `COOKIE:SMSESSION=…;SSOTOKEN=…` (Details: Hub-README).
## Installation
Unsignierte Datei: [Bank of America.lua](https://raw.githubusercontent.com/rosch100/Bank-of-America-MoneyMoney/main/Bank%20of%20America.lua)
Datei nach `~/Library/Containers/com.moneymoney-app.retail/Data/Library/Application Support/MoneyMoney/Extensions` kopieren, oder im Klon `./link_ext.sh` ausführen.
Unsignierte Plugins: MoneyMoney-**Beta**, Signaturprüfung in den Erweiterungseinstellungen aus.
## Tests
```sh
python3 tests/test_conformance.py
luajit tests/test_boa_login.lua

```
Aus dem Repo-Root ausführen.

## Lizenz
MIT — siehe [LICENSE](LICENSE).
