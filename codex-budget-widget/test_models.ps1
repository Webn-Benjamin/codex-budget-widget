$ErrorActionPreference='Stop'
. "$PSScriptRoot\widget.ps1" -Preview -PreviewState settings -Language en -PreviewModel spark
$dataDir=Join-Path ([IO.Path]::GetTempPath()) ('BudgetCodex-Models-'+[Guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($dataDir)|Out-Null
function Assert($condition,$message) { if (-not $condition) { throw $message } }
Assert ($ui.ShortValue.Text -eq '68 %') 'Spark 5h missing'
$ui.ModelCodex.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
Assert ($ui.ShortPanel.Visibility -eq 'Collapsed') 'Codex should hide Spark window'
$ui.ModelSpark.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
Assert ($ui.ShortPanel.Visibility -eq 'Visible') 'Spark window not restored'
Assert ((Get-Content (Join-Path $dataDir 'model.json') -Raw|ConvertFrom-Json).model -eq 'spark') 'Selection not saved'
$script:lastEnvelope.models.spark.short.remaining=0
Show-Envelope $script:lastEnvelope
Assert ($ui.Context.Text -like '*5-hour limit reached*') 'Exhaustion not visible'
$script:lastEnvelope.models.spark.short.reset=1
Show-Envelope $script:lastEnvelope
Assert ($ui.ShortValue.Text -eq '—') 'Expired quota shown as valid'
$script:lastEnvelope.models.spark=[pscustomobject]@{ok=$false}
Show-Envelope $script:lastEnvelope
Assert ($ui.Used.Text -eq '—') 'Old model values leaked'
Assert ($ui.Daily.Text -eq '—') 'Old daily target leaked'
Write-Output 'PASS: model switch, persistence, exhaustion, expiry, unavailable model.'

foreach ($model in @('codex','spark')) {
 Set-Model $model
 Show-Envelope ([pscustomobject]@{ok=$false;error_code='login_required'})
 Assert ($ui.Context.Text -eq 'Signed out · run codex login') 'CLI sign-in error missing'
 Set-Language fr
 Assert ($ui.Context.Text -eq 'Compte déconnecté · lancez codex login') 'French CLI error missing'
 Set-Language en
}
Write-Output 'PASS: CLI errors on first launch and language switch for both models.'

Show-Envelope ([pscustomobject]@{ok=$false;error_code='wsl_login_required';source='WSL / Debian'})
Assert ($ui.Context.Text -eq 'In WSL: run codex login') 'WSL login instruction missing'
Assert ($ui.Status.ToolTip -eq 'WSL / Debian') 'WSL source missing'
Set-Language fr
Assert ($ui.Context.Text -eq 'Dans WSL : lancez codex login') 'French WSL instruction missing'
Write-Output 'PASS: WSL login and source tooltip in FR/EN.'

Set-Language en
$script:sourceOptions=@('auto','windows','wsl:Debian')
Update-SourceChoices
$ui.SourceChoice.SelectedIndex=2
Assert ((Get-Content (Join-Path $dataDir 'source.json') -Raw|ConvertFrom-Json).source -eq 'wsl:Debian') 'WSL selection not saved'
Assert ($ui.Used.Text -eq '—') 'Old Windows quota visible after source switch'
Assert (Test-Path (Join-Path $dataDir 'refresh')) 'Source switch did not request refresh'
$old=$script:lastState
Show-Envelope ([pscustomobject]@{requested_source='auto';ok=$true})
Assert ([object]::ReferenceEquals($old,$script:lastState)) 'Old source response accepted'
Show-Envelope ([pscustomobject]@{requested_source='wsl:Debian';ok=$false;source='WSL / Debian';error_code='wsl_login_required'})
Assert ($ui.Status.ToolTip -eq 'WSL / Debian') 'Selected source response rejected'
Set-Language fr
Assert ($ui.SourceChoice.SelectedItem.Tag -eq 'wsl:Debian') 'Language changed source'
$ui.SourceChoice.SelectedIndex=1
$ui.SourceChoice.SelectedIndex=1
Assert ((Get-Content (Join-Path $dataDir 'source.json') -Raw|ConvertFrom-Json).source -eq 'windows') 'Repeated source selection failed'
Write-Output 'PASS: explicit source persistence, refresh, stale response rejection, FR/EN and repeated selection.'

@{version='1.2.2';entries=@(@{at=1800000000;event='error';source='WSL / Debian';stage='account/read';code='read_failed';rpc_code=-32000})}|ConvertTo-Json -Depth 5|Set-Content -LiteralPath (Join-Path $dataDir 'diagnostics.json') -Encoding UTF8
Update-Diagnostic
Assert ($ui.DiagnosticConsole.Text -like '*WSL / Debian*RPC -32000*') 'Support details missing'
Assert ($ui.DiagnosticConsole.IsReadOnly) 'Console must be read-only'
Set-Language en
Assert ((Get-DiagnosticReport) -like '*Error*') 'English report missing'
Set-Language fr
Assert ((Get-DiagnosticReport) -like '*Erreur*') 'French report missing'
Write-Output 'PASS: diagnostic report, error details, read-only console, FR/EN.'
