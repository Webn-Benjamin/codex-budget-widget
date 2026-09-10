$ErrorActionPreference='Stop'
. "$PSScriptRoot\widget.ps1" -Preview -PreviewState settings
$dataDir=Join-Path ([IO.Path]::GetTempPath()) ('BudgetCodex-Apply-'+[Guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($dataDir)|Out-Null
$workdaysFile=Join-Path $dataDir 'workdays.json'
$script:chosenDays=@(0,1,2,3,4,5,6)
[IO.File]::WriteAllText($workdaysFile,(@{workdays=$chosenDays}|ConvertTo-Json))
function Select-Days($days) { foreach ($box in $dayBoxes) { $box.IsChecked=$days -contains [int]$box.Tag }; $ui.SettingsPanel.Visibility='Visible' }
function Apply-Days { $ui.SaveDays.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent)) }
function Assert($condition,$message) { if (-not $condition) { throw $message } }
Select-Days @(0,1,2,3,4,5,6)
$before=[IO.File]::GetLastWriteTimeUtc($workdaysFile)
Apply-Days
Assert ([IO.File]::GetLastWriteTimeUtc($workdaysFile) -eq $before) 'Unchanged selection rewrote configuration'
Assert ($ui.SettingsPanel.Visibility -eq 'Collapsed') 'Unchanged selection did not close settings'
Select-Days @(0,1,2,3,4)
Apply-Days
Assert (((Get-Content $workdaysFile -Raw|ConvertFrom-Json).workdays -join ',') -eq '0,1,2,3,4') 'Changed selection not saved'
Assert (($chosenDays -join ',') -eq '0,1,2,3,4') 'Saved selection cache not updated'
$before=[IO.File]::GetLastWriteTimeUtc($workdaysFile)
1..3 | ForEach-Object { Apply-Days }
Assert ([IO.File]::GetLastWriteTimeUtc($workdaysFile) -eq $before) 'Repeated apply rewrote configuration'
Select-Days @()
Apply-Days
Assert ($ui.SettingsPanel.Visibility -eq 'Visible') 'Empty selection accepted'
Select-Days @(0,1,2,3,4,5,6)
$lock=[IO.File]::Open($workdaysFile,[IO.FileMode]::Open,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
try { Apply-Days; Assert ($ui.Context.Text -like 'Enregistrement impossible*') 'Write failure not reported'; Assert (($chosenDays -join ',') -eq '0,1,2,3,4') 'Failed write changed saved selection' } finally { $lock.Dispose() }
Apply-Days
Assert (((Get-Content $workdaysFile -Raw|ConvertFrom-Json).workdays.Count) -eq 7) 'Retry did not save'
Select-Days @(2)
Apply-Days
Assert (((Get-Content $workdaysFile -Raw|ConvertFrom-Json).workdays -join ',') -eq '2') 'Single-day selection failed'
Assert (@(Get-ChildItem $dataDir -Filter '*.tmp').Count -eq 0) 'Temporary files left behind'
$workdaysFile=Join-Path $dataDir 'first-run.json'
Select-Days @(0,1)
Apply-Days
Assert (Test-Path $workdaysFile) 'First save failed'
Write-Output 'PASS: unchanged, changed, repeated, empty, locked file, retry, single day, first save.'
