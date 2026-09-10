$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationFramework
$french=[Globalization.CultureInfo]::CurrentUICulture.TwoLetterISOLanguageName -eq 'fr'
try { $savedLanguage=(Get-Content (Join-Path $PSScriptRoot 'data\language.json') -Raw -Encoding UTF8 | ConvertFrom-Json).language; if ($savedLanguage -in @('fr','en')) { $french=$savedLanguage -eq 'fr' } } catch {}
try {
 $codex=Get-Command codex.exe,codex -ErrorAction SilentlyContinue | Select-Object -First 1
 $bundled=@(Get-ChildItem -Path (Join-Path $env:LOCALAPPDATA 'OpenAI\Codex\bin\*\codex.exe') -ErrorAction SilentlyContinue)
 if (-not $codex -and $bundled.Count -eq 0) {
  $message=if ($french) { "Installez et ouvrez Codex, puis connectez votre compte. Relancez ensuite Budget Codex depuis le raccourci du bureau." } else { 'Install and open Codex, then sign in. Afterwards, open Budget Codex again using the desktop shortcut.' }
  [Windows.MessageBox]::Show($message,'Budget Codex','OK','Information') | Out-Null
  exit
 }
 & (Join-Path $PSScriptRoot 'widget.ps1')
} catch {
 $message=if ($french) { "Le widget ne peut pas démarrer. Réinstallez Budget Codex, puis réessayez." } else { 'The widget could not start. Please reinstall Budget Codex and try again.' }
 [Windows.MessageBox]::Show($message+[Environment]::NewLine+$_.Exception.Message,'Budget Codex','OK','Error') | Out-Null
}
