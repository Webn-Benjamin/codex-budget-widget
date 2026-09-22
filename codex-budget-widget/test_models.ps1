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

Set-Language en
$state=[pscustomobject]@{ok=$true;updated=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds();reset=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()+432000;remaining=47;used=53;standard_cap=(100.0/7);cap=(100.0/7);workdays=@(0,1,2,3,4,5,6);working_today=$true;uncertain=$true;today_low=0;today_high=53;opening_bonus_low=0;opening_bonus_high=100;bonus_low=0;bonus_high=100}
Show-State $state
Assert ($ui.Used.Text -eq "Daily budget`nused up".Replace("`n",[Environment]::NewLine)) 'Zero daily budget label missing'
Assert ($ui.Context.Text -eq 'You still have 47% left this week') 'Weekly availability not clarified'
Assert ($ui.GlobalRemaining.Text -like '47*') 'Weekly quota changed'
Set-Language fr
Assert ($ui.Used.Text -like 'Budget du jour*épuisé') 'French exhausted label missing'
$state.working_today=$false
Show-State $state
Assert ($ui.Used.Text -eq 'Jour de repos') 'Day off described as overspending'
$state.remaining=0;$state.used=100
Show-State $state
Assert ($ui.Used.Text -like 'Quota hebdomadaire*épuisé') 'Weekly exhaustion confused with daily budget'
$state.remaining=99;$state.used=1;$state.working_today=$true
Show-State $state
Assert ($ui.Used.FontSize -eq 42) 'Numeric display size not restored'
Write-Output 'PASS: empty daily budget, remaining weekly quota, day off, weekly exhaustion and numeric recovery.'

$state.uncertain=$false;$state.today_low=2;$state.cap=20
$state.opening_bonus_low=-10;$state.opening_bonus_high=-10
$state | Add-Member carry_low -10 -Force
$state | Add-Member carry_high -10 -Force
$state | Add-Member available 8 -Force
Show-State $state
Assert ($ui.Total.Text -eq ' / 10 %') 'Deficit not deducted from daily total'
Assert ($ui.BonusLabel.Text -eq 'Malus' -and $ui.Bonus.Text -eq '-10 %') 'French deficit missing'
Set-Language en
Assert ($ui.BonusLabel.Text -eq 'Deficit' -and $ui.Bonus.Text -eq '-10 %') 'English deficit missing'
Assert ($ui.Context.Text -eq 'Daily budget reduced by carried deficit') 'Deficit explanation missing'
$state.opening_bonus_low=-40;$state.opening_bonus_high=-40;$state.available=0
Show-State $state
Assert ($ui.Total.Text -eq ' / 0 %') 'Negative daily total displayed'
$state.uncertain=$true;$state.used=99;$state.remaining=1
Show-State $state
Assert ($ui.BonusLabel.Text -eq 'Deficit' -and $ui.Bonus.Text.StartsWith('-')) 'Snapshot deficit hidden'
$state.used=0;$state.remaining=100
Show-State $state
Assert ($ui.BonusLabel.Text -eq 'Bonus' -and $ui.Bonus.Text.StartsWith('+')) 'Bonus not restored'
Write-Output 'PASS: signed carry, daily total, deep deficit, snapshots and FR/EN.'

$state | Add-Member tomorrow_available 15 -Force
$state | Add-Member tomorrow_working $true -Force
$state | Add-Member tomorrow_reset $false -Force
Set-Language en
Show-State $state
Assert ($ui.TomorrowValue.Text -eq '15 %' -and $ui.TomorrowLabel.Text -eq 'Tomorrow') 'Tomorrow forecast missing'
$state.tomorrow_available=12
Show-State $state
Assert ($ui.TomorrowValue.Text -eq '12 %') 'Forecast not refreshed'
Set-Language fr
Assert ($ui.TomorrowLabel.Text -eq 'Demain') 'French forecast missing'
$state.tomorrow_available=$null;$state.tomorrow_reset=$true
Show-State $state
Assert ($ui.TomorrowValue.Text -eq '—' -and $ui.TomorrowHint.Text -like 'Reset*') 'Reset forecast invented'
Write-Output 'PASS: tomorrow forecast refresh, FR/EN and reset boundary.'

$state | Add-Member average_usage 20 -Force
$state | Add-Member projected_tomorrow 12 -Force
Set-Language fr
Show-State $state
Assert ($ui.WeeklyAverage.Text -like '*20 %*' -and $ui.ProjectionValue.Text -eq '≈ 12 %') 'French projection missing'
Set-Language en
Assert ($ui.ProjectionLabel.Text -eq 'Tomorrow at this pace') 'English projection missing'
$state.projected_tomorrow=8;Show-State $state
Assert ($ui.ProjectionValue.Text -eq '≈ 8 %') 'Projection not refreshed'
$state.average_usage=$null;$state.projected_tomorrow=$null;Show-State $state
Assert ($ui.ProjectionValue.Text -eq '—' -and $ui.WeeklyAverage.Text -like '*one working day*') 'Missing average guessed'
Write-Output 'PASS: weekly average and projection in FR/EN, refresh and insufficient data.'


$state | Add-Member remaining_plan ([pscustomobject]@{available=8;daily=11;total_today=11;days=3;day_equivalents=3;tomorrow_available=16.5;projected_tomorrow=11.5;working_today=$true;tomorrow_working=$true}) -Force
foreach ($lang in @('fr','en')) {
 Set-Language $lang
 $state.today_low=3;$state.uncertain=$false;$state.remaining_plan.available=8
 Show-State $state
 Assert ($ui.Used.Text -eq '3 %' -and $ui.Total.Text -eq ' / 8 %') 'Used/remaining ratio incorrect'
 Assert ([Math]::Abs($ui.Fill.Width-312*3/11) -lt 0.001) 'Progress must use used plus remaining'
 Assert ($ui.UsageLabel.Text -like '*/*') 'Ratio labels missing'
 $state.uncertain=$true;Show-State $state
 Assert ($ui.Used.Text -eq '≥ 3 %' -and $ui.Total.Text -eq ' / 8 %') 'Incomplete history removed ratio'
 Assert ($ui.Track.Visibility -eq 'Visible') 'Incomplete history removed bar'
 $state.today_low=0;$state.remaining_plan.available=20.2;Show-State $state
 Assert ($ui.Used.Text -eq '≥ 0 %' -and $ui.Total.Text -ne '') 'Missing reading presented as exact zero'
 $state.today_low=12;$state.uncertain=$false;$state.remaining_plan.available=0;Show-State $state
 Assert ($ui.Total.Text -eq ' / 0 %' -and $ui.Fill.Width -eq 312) 'Exhaustion ratio incorrect'
 $state.remaining_plan.working_today=$false;Show-State $state
 Assert ($ui.Total.Text -eq '' -and $ui.Track.Visibility -eq 'Collapsed') 'Day off regressed'
 $state.remaining_plan.working_today=$true;$state.today_low=4;$state.remaining_plan.available=7;Show-State $state
 Assert ($ui.Total.Text -eq ' / 7 %' -and $ui.Track.Visibility -eq 'Visible') 'Refresh recovery failed'
}
Write-Output 'PASS: daily used/remaining, progress, incomplete history, zero, exhaustion, days off and recovery in FR/EN.'
