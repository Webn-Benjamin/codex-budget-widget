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
