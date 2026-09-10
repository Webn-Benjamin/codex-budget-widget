# Build the Windows installer

Requires Inno Setup 6.7.3 or compatible, available from https://jrsoftware.org/isdl.php.

Run `ISCC.exe BudgetCodex.iss` from this directory. The public artifact is `../dist/Budget-Codex-Setup.exe`. Only files explicitly listed in `[Files]` are packaged: never add the `data` folder or wildcard the project directory.

The installer is per-user, Windows 10+ x64-compatible, with French/English language detection. The monitor executable bundles its Python runtime. Updates replace program files and retain local data. Uninstall removes installed files and shortcuts but retains generated history.

`ISCC.exe /DTestBuild=1 BudgetCodex.iss` builds a separate test product without shortcuts, auto-launch or the live widget mutex. This allows isolated install/update/uninstall checks without changing an existing installation. Do not distribute the test executable.

The current installer is unsigned. Public releases should be signed with the publisher’s code-signing certificate when available; do not claim verified-publisher status without signing. Consult Inno Setup’s license for commercial use.
