# Build and test / Compiler et tester

## English

The repository contains the Windows widget, a separate on-demand Codex plugin and the unsigned Windows installer (v1.0.3). Personal usage history is never included.

On Windows with Python 3.12 and Inno Setup 6.7.3 installed:

```powershell
py -3.12 -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements-build.txt
cd codex-budget-widget
..\.venv\Scripts\python.exe -m unittest discover -p "test_*.py" -v
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File test_apply.ps1
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File test_language.ps1
..\.venv\Scripts\python.exe -m PyInstaller --noconfirm --onefile --noconsole --name BudgetMonitor --distpath bin --collect-all tzdata --collect-all tzlocal monitor.py
& "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" installer\BudgetCodex.iss
(Get-FileHash dist\Budget-Codex-Setup.exe -Algorithm SHA256).Hash.ToLowerInvariant() + '  Budget-Codex-Setup.exe' | Set-Content dist\SHA256SUMS.txt -Encoding ascii
```

Adjust the compiler path to your Inno Setup installation. The installer is written to `codex-budget-widget/dist/Budget-Codex-Setup.exe`. Do not package `data`, test installations or compiler tools. Close any running widget before testing an update. The installer test variant is documented in [installer/README.md](codex-budget-widget/installer/README.md).

The PowerShell regression test uses temporary settings and synthetic preview data, without changing your saved work schedule. Calculation tests use synthetic quota histories. No live account is needed for these tests.

Installer compiler: https://jrsoftware.org/isdl.php. The compiler is not bundled; review its license for commercial use. The widget's MIT license does not replace third-party runtime licenses. Releases are currently unsigned.

## Français

Le dépôt contient le widget Windows, le plugin Codex à la demande et l’installateur Windows non signé (v1.0.3). Aucun historique personnel n’est publié.

Les commandes ci-dessus installent les dépendances dans un environnement Python 3.12, exécutent les tests, reconstruisent le suivi puis l’installateur. Adaptez le chemin d’Inno Setup à votre installation.

Le fichier à distribuer est `codex-budget-widget/dist/Budget-Codex-Setup.exe`. N’ajoutez jamais le dossier `data`, les installations de test ou les outils du compilateur au paquet. Fermez le widget avant de tester une mise à jour.

Les tests utilisent des données fictives et des réglages temporaires ; ils n’ont pas besoin d’un compte connecté. Le compilateur Inno Setup n’est pas inclus. Consultez sa licence pour un usage commercial. La licence MIT du projet ne remplace pas les licences des composants tiers.
