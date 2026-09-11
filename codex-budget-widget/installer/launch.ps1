$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationFramework
$french=[Globalization.CultureInfo]::CurrentUICulture.TwoLetterISOLanguageName -eq 'fr'
try { $savedLanguage=(Get-Content (Join-Path $PSScriptRoot 'data\language.json') -Raw -Encoding UTF8 | ConvertFrom-Json).language; if ($savedLanguage -in @('fr','en')) { $french=$savedLanguage -eq 'fr' } } catch {}
try {
 & (Join-Path $PSScriptRoot 'widget.ps1')
} catch {
 $message=if ($french) { "Le widget ne peut pas démarrer. Réinstallez Budget Codex, puis réessayez." } else { 'The widget could not start. Please reinstall Budget Codex and try again.' }
 [Windows.MessageBox]::Show($message+[Environment]::NewLine+$_.Exception.Message,'Budget Codex','OK','Error') | Out-Null
}
