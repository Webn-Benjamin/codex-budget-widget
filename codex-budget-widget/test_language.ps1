$ErrorActionPreference='Stop'
. "$PSScriptRoot\widget.ps1" -Preview -PreviewState settings -Language fr
$dataDir=Join-Path ([IO.Path]::GetTempPath()) ('BudgetCodex-Language-'+[Guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($dataDir)|Out-Null
function Assert($condition,$message) { if (-not $condition) { throw $message } }
$selected=@($dayBoxes|Where-Object IsChecked|ForEach-Object Tag) -join ','
$used=$ui.Used.Text
$ui.LangEN.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
Assert ($ui.UsageLabel.Text -eq 'Used today') 'English main label'
Assert ($ui.SaveDays.Content -eq 'Apply') 'English button'
Assert ($dayBoxes[0].Content -eq 'Mon') 'English weekdays'
Assert ((Get-Language '') -eq 'en') 'English persistence'
Assert ((Format-Points 14.3) -eq '14.3') 'English decimal'
Assert ($ui.Used.Text -eq $used) 'Usage changed'
Assert ((@($dayBoxes|Where-Object IsChecked|ForEach-Object Tag) -join ',') -eq $selected) 'Schedule changed'
$ui.LangEN.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
$ui.LangFR.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
Assert ((Get-Language '') -eq 'fr') 'French persistence'
Assert ($ui.SaveDays.Content -eq 'Appliquer') 'French button'
Assert ((Format-Points 14.3) -eq '14,3') 'French decimal'
$script:lastState.ok=$false
Set-Language 'en'
Assert ($ui.Status.Text -eq 'Offline') 'English offline state'
Assert ($ui.Context.Text -eq 'Data unavailable · retrying automatically') 'English offline message'
$script:lastState.ok=$true; $script:lastState.uncertain=$true
Set-Language 'en'
Assert ($ui.UsageLabel.Text -eq 'Available today') 'English partial state'
Write-Output 'PASS: FR/EN clicks, repeated selection, persistence, decimals, stable usage/schedule, offline and partial states.'
