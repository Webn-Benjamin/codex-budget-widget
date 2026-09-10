param([switch]$Preview, [ValidateSet('live','normal','bonus','partial','offline','settings')][string]$PreviewState='live')
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
$dataDir = Join-Path $PSScriptRoot 'data'
[IO.Directory]::CreateDirectory($dataDir) | Out-Null
$ownsMutex = $false
$mutex = [Threading.Mutex]::new($true, 'Local\CodexBudgetWidget_v1', [ref]$ownsMutex)
if (-not $ownsMutex -and -not $Preview) { $mutex.Dispose(); exit }
[xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
 xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Title="Budget Codex"
 Width="360" Height="378" WindowStyle="None" AllowsTransparency="True" Background="Transparent"
 ResizeMode="NoResize" Topmost="True" WindowStartupLocation="Manual"
 FontFamily="Segoe UI" FontSize="12" Foreground="#F4F7FA" UseLayoutRounding="True">
 <Window.Resources>
  <Style x:Key="ControlButton" TargetType="Button">
   <Setter Property="Foreground" Value="#AFBBC8"/><Setter Property="Background" Value="Transparent"/>
   <Setter Property="BorderBrush" Value="Transparent"/><Setter Property="BorderThickness" Value="1"/>
   <Setter Property="Cursor" Value="Hand"/><Setter Property="Padding" Value="8,5"/>
   <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Button">
    <Border x:Name="ButtonSurface" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="5" Padding="{TemplateBinding Padding}">
     <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
    </Border>
    <ControlTemplate.Triggers>
     <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="ButtonSurface" Property="Background" Value="#303842"/><Setter Property="Foreground" Value="#F4F7FA"/></Trigger>
     <Trigger Property="IsKeyboardFocused" Value="True"><Setter Property="BorderBrush" Value="#6DE0B9"/></Trigger>
     <Trigger Property="IsPressed" Value="True"><Setter TargetName="ButtonSurface" Property="Background" Value="#424C57"/></Trigger>
     <Trigger Property="IsEnabled" Value="False"><Setter Property="Opacity" Value="0.45"/></Trigger>
    </ControlTemplate.Triggers>
   </ControlTemplate></Setter.Value></Setter>
  </Style>
  <Style x:Key="DaySelector" TargetType="CheckBox">
   <Setter Property="Foreground" Value="#AFBBC8"/>
   <Setter Property="Background" Value="#22282F"/>
   <Setter Property="BorderBrush" Value="#46515E"/>
   <Setter Property="FontSize" Value="11"/>
   <Setter Property="FontWeight" Value="SemiBold"/>
   <Setter Property="Height" Value="44"/>
   <Setter Property="Margin" Value="2,0"/>
   <Setter Property="Cursor" Value="Hand"/>
   <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
   <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="CheckBox">
    <Border x:Name="DaySurface" CornerRadius="7" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="1">
     <Grid>
      <StackPanel VerticalAlignment="Center" HorizontalAlignment="Center">
       <ContentPresenter HorizontalAlignment="Center"/>
       <Path x:Name="SelectedMark" Visibility="Hidden" Margin="0,5,0,0" Width="9" Height="6" Stroke="{TemplateBinding Foreground}" StrokeThickness="1.6" StrokeStartLineCap="Round" StrokeEndLineCap="Round" Data="M 1,3 L 3.5,5 L 8,1"/>
      </StackPanel>
      <Border x:Name="DayFocus" Margin="2" CornerRadius="5" BorderThickness="1" BorderBrush="{TemplateBinding Foreground}" Visibility="Hidden" IsHitTestVisible="False"/>
     </Grid>
    </Border>
    <ControlTemplate.Triggers>
     <Trigger Property="IsMouseOver" Value="True"><Setter Property="Background" Value="#303943"/><Setter Property="BorderBrush" Value="#8A9AA9"/><Setter Property="Foreground" Value="#F4F7FA"/></Trigger>
     <Trigger Property="IsChecked" Value="True"><Setter Property="Background" Value="#6DE0B9"/><Setter Property="BorderBrush" Value="#6DE0B9"/><Setter Property="Foreground" Value="#102C24"/><Setter TargetName="SelectedMark" Property="Visibility" Value="Visible"/></Trigger>
     <MultiTrigger><MultiTrigger.Conditions><Condition Property="IsChecked" Value="True"/><Condition Property="IsMouseOver" Value="True"/></MultiTrigger.Conditions><Setter Property="Background" Value="#93EBCD"/><Setter Property="BorderBrush" Value="#93EBCD"/></MultiTrigger>
     <Trigger Property="IsPressed" Value="True"><Setter TargetName="DaySurface" Property="Opacity" Value="0.8"/></Trigger>
     <Trigger Property="IsKeyboardFocused" Value="True"><Setter TargetName="DayFocus" Property="Visibility" Value="Visible"/></Trigger>
     <Trigger Property="IsEnabled" Value="False"><Setter TargetName="DaySurface" Property="Opacity" Value="0.4"/></Trigger>
    </ControlTemplate.Triggers>
   </ControlTemplate></Setter.Value></Setter>
  </Style>
 </Window.Resources>
 <Border Background="#171B20" BorderBrush="#38414B" BorderThickness="1" CornerRadius="12">
  <StackPanel>
   <Grid x:Name="DragArea" Height="53" Background="Transparent" Margin="17,0,10,0">
    <Grid.ColumnDefinitions><ColumnDefinition/><ColumnDefinition Width="32"/><ColumnDefinition Width="32"/><ColumnDefinition Width="32"/></Grid.ColumnDefinitions>
    <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
     <Ellipse x:Name="ConnectionDot" Width="6" Height="6" Fill="#AFBBC8" Margin="0,0,9,0"/>
     <TextBlock Text="Codex" FontWeight="SemiBold" FontSize="14"/>
     <TextBlock Text=" / Budget" Foreground="#AFBBC8" FontSize="14"/>
    </StackPanel>
    <Button x:Name="SettingsButton" Grid.Column="1" Style="{StaticResource ControlButton}" Height="30" Padding="6" ToolTip="Réglages" AutomationProperties.Name="Réglages">
     <Path Width="16" Height="16" Stretch="Uniform" Stroke="{Binding Foreground, RelativeSource={RelativeSource AncestorType=Button}}" StrokeThickness="1.5" Data="M 1,4 L 15,4 M 1,12 L 15,12 M 5,1 L 5,7 M 11,9 L 11,15"/>
    </Button>
    <Button x:Name="Minimize" Grid.Column="2" Style="{StaticResource ControlButton}" Height="30" Padding="6" ToolTip="Réduire" AutomationProperties.Name="Réduire">
     <Path Width="12" Height="12" Stroke="{Binding Foreground, RelativeSource={RelativeSource AncestorType=Button}}" StrokeThickness="1.5" Data="M 1,7 L 11,7"/>
    </Button>
    <Button x:Name="Close" Grid.Column="3" Style="{StaticResource ControlButton}" Height="30" Padding="6" ToolTip="Fermer" AutomationProperties.Name="Fermer">
     <Path Width="12" Height="12" Stroke="{Binding Foreground, RelativeSource={RelativeSource AncestorType=Button}}" StrokeThickness="1.5" Data="M 2,2 L 10,10 M 10,2 L 2,10"/>
    </Button>
   </Grid>
   <StackPanel Margin="22,7,22,0">
    <DockPanel>
     <TextBlock x:Name="UsageLabel" Text="Utilisé aujourd’hui" FontSize="14" FontWeight="SemiBold"/>
     <TextBlock x:Name="Date" HorizontalAlignment="Right" Foreground="#AFBBC8"/>
    </DockPanel>
    <StackPanel Orientation="Horizontal" Margin="0,7,0,0" Height="57">
     <TextBlock x:Name="Used" Text="—" FontSize="42" FontWeight="SemiBold" Typography.NumeralAlignment="Tabular" Foreground="#6DE0B9"/>
     <TextBlock x:Name="Total" Text=" / —" FontSize="23" Foreground="#AFBBC8" VerticalAlignment="Bottom" Margin="6,0,0,9" Typography.NumeralAlignment="Tabular"/>
    </StackPanel>
    <Grid x:Name="Track" Height="7" Margin="0,9,0,9" ClipToBounds="True">
     <Border Background="#303842" CornerRadius="3"/>
     <Border x:Name="Fill" Width="0" HorizontalAlignment="Left" Background="#6DE0B9" CornerRadius="3"/>
    </Grid>
    <TextBlock x:Name="Context" Text="Premier relevé en cours…" Foreground="#AFBBC8" FontSize="11" Height="29" TextWrapping="Wrap"/>
    <Border Height="1" Background="#303842" Margin="0,10,0,14"/>
    <Grid>
     <Grid.ColumnDefinitions><ColumnDefinition/><ColumnDefinition Width="1"/><ColumnDefinition/></Grid.ColumnDefinitions>
     <StackPanel><TextBlock Text="Par jour" Foreground="#AFBBC8"/><TextBlock x:Name="Daily" Text="—" FontSize="24" FontWeight="SemiBold" Margin="0,2,0,0"/></StackPanel>
     <Border Grid.Column="1" Background="#303842" Margin="0,2,0,2"/>
     <StackPanel Grid.Column="2" Margin="20,0,0,0"><TextBlock Text="Bonus" Foreground="#AFBBC8"/><TextBlock x:Name="Bonus" Text="—" FontSize="24" FontWeight="SemiBold" Foreground="#F0CA8D" Margin="0,2,0,0" ToolTip="Bonus reporté encore disponible. Le total du jour inclut le bonus du début de journée."/></StackPanel>
    </Grid>
   </StackPanel>
   <Border BorderBrush="#303842" BorderThickness="0,1,0,0" Margin="22,12,22,0" Padding="0,9,0,0">
    <DockPanel><TextBlock Text="Quota global restant" Foreground="#AFBBC8" VerticalAlignment="Center"/><TextBlock x:Name="GlobalRemaining" Text="— / 100 %" HorizontalAlignment="Right" FontSize="18" FontWeight="SemiBold"/></DockPanel>
   </Border>
   <Grid Margin="17,9,15,7" Height="25">
    <TextBlock x:Name="Status" Text="Connexion…" Foreground="#AFBBC8" FontSize="10" VerticalAlignment="Center"/>
    <Button x:Name="Refresh" Content="Actualiser" Style="{StaticResource ControlButton}" HorizontalAlignment="Right" FontSize="10" Padding="6,2"/>
   </Grid>
   <Border x:Name="SettingsPanel" Visibility="Collapsed" BorderBrush="#303842" BorderThickness="0,1,0,0" Padding="20,15,20,16">
    <StackPanel>
     <DockPanel><TextBlock Text="Jours travaillés" FontWeight="SemiBold" VerticalAlignment="Center"/><Button x:Name="SaveDays" Content="Appliquer" HorizontalAlignment="Right" Style="{StaticResource ControlButton}" Background="#303842"/></DockPanel>
     <UniformGrid x:Name="Workdays" Columns="7" Margin="0,12,0,16"/>
     <CheckBox x:Name="Pin" Content="Toujours au premier plan" IsChecked="True" Foreground="#F4F7FA"/>
     <TextBlock x:Name="Weekly" Text="Quota hebdomadaire : —" Foreground="#AFBBC8" Margin="0,15,0,4"/>
     <TextBlock x:Name="Reset" Text="Reset : —" Foreground="#AFBBC8"/>
    </StackPanel>
   </Border>
  </StackPanel>
 </Border>
</Window>
'@
$window = [Windows.Markup.XamlReader]::Load([Xml.XmlNodeReader]::new($xaml))
$ui = @{}
'UsageLabel','GlobalRemaining','DragArea','ConnectionDot','SettingsButton','Minimize','Close','Date','Used','Total','Track','Fill','Context','Daily','Bonus','Status','Refresh','SettingsPanel','SaveDays','Workdays','Pin','Weekly','Reset' | ForEach-Object { $ui[$_] = $window.FindName($_) }
$window.Left = [Math]::Max(0, [Windows.SystemParameters]::WorkArea.Right - 380)
$window.Top = [Math]::Max(0, [Windows.SystemParameters]::WorkArea.Bottom - 398)
$settings = Join-Path $dataDir 'window.json'
if (Test-Path -LiteralPath $settings) {
 try {
  $saved = Get-Content -LiteralPath $settings -Raw | ConvertFrom-Json
  $window.Left = [Math]::Max(0, [Math]::Min([double]$saved.left, [Windows.SystemParameters]::WorkArea.Right - 360))
  $window.Top = [Math]::Max(0, [Math]::Min([double]$saved.top, [Windows.SystemParameters]::WorkArea.Bottom - 378))
  $window.Topmost = [bool]$saved.pin
  $ui.Pin.IsChecked = $window.Topmost
 } catch { }
}
$ui.DragArea.Add_MouseLeftButtonDown({ if ($_.OriginalSource -isnot [Windows.Shapes.Path] -and $_.OriginalSource -isnot [Windows.Controls.Border]) { try { $window.DragMove() } catch { } } })
$ui.Close.Add_Click({ $window.Close() })
$ui.Minimize.Add_Click({ $window.WindowState = 'Minimized' })
$ui.SettingsButton.Add_Click({
 if ($ui.SettingsPanel.Visibility -eq 'Collapsed') {
  $ui.SettingsPanel.Visibility = 'Visible'; $window.Height = 603
  $window.Top = [Math]::Max(0,[Math]::Min($window.Top,[Windows.SystemParameters]::WorkArea.Bottom-603))
 } else { $ui.SettingsPanel.Visibility = 'Collapsed'; $window.Height = 378 }
})
$window.Add_KeyDown({ if ($_.Key -eq 'Escape' -and $ui.SettingsPanel.Visibility -eq 'Visible') { $ui.SettingsPanel.Visibility='Collapsed'; $window.Height=378; $_.Handled=$true } })
$ui.Pin.Add_Click({ $window.Topmost = [bool]$ui.Pin.IsChecked })
$ui.Refresh.Add_Click({ [IO.File]::WriteAllText((Join-Path $dataDir 'refresh'), '') })
$workdaysFile = Join-Path $dataDir 'workdays.json'
$chosenDays = @(0,1,2,3,4)
if (Test-Path -LiteralPath $workdaysFile) { try { $chosenDays=@((Get-Content -LiteralPath $workdaysFile -Raw -Encoding UTF8 | ConvertFrom-Json).workdays) } catch { } }
$dayBoxes = @()
$dayNames = @('Lun','Mar','Mer','Jeu','Ven','Sam','Dim')
for ($i=0;$i -lt 7;$i++) {
 $box=[Windows.Controls.CheckBox]::new(); $box.Content=$dayNames[$i]; $box.Tag=$i; $box.Style=$window.FindResource('DaySelector'); $box.ToolTip=@('Lundi','Mardi','Mercredi','Jeudi','Vendredi','Samedi','Dimanche')[$i]; [Windows.Automation.AutomationProperties]::SetName($box,$box.ToolTip); $box.IsChecked=$chosenDays -contains $i
 $ui.Workdays.Children.Add($box) | Out-Null; $dayBoxes += $box
}
$script:pendingDays = $null
$ui.SaveDays.Add_Click({
 $selected=@($dayBoxes | Where-Object { $_.IsChecked } | ForEach-Object { [int]$_.Tag })
 if ($selected.Count -eq 0) { $ui.Context.Text='Choisis au moins un jour travaillé.'; return }
 if (($selected -join ',') -eq ($chosenDays -join ',')) {
  $ui.SettingsPanel.Visibility='Collapsed'; $window.Height=378
  return
 }
 $tempConfig=$workdaysFile+'.'+[Guid]::NewGuid().ToString('N')+'.tmp'
 try {
  [IO.File]::WriteAllText($tempConfig,(@{workdays=$selected}|ConvertTo-Json),[Text.UTF8Encoding]::new($false))
  # An explicit backup path avoids PowerShell 5.1 converting $null to an empty path.
  if (Test-Path -LiteralPath $workdaysFile) { [IO.File]::Replace($tempConfig,$workdaysFile,$workdaysFile+'.bak') } else { [IO.File]::Move($tempConfig,$workdaysFile) }
  $script:chosenDays=$selected
  $script:pendingDays = $selected -join ','
  [IO.File]::WriteAllText((Join-Path $dataDir 'refresh'),'')
  $ui.SettingsPanel.Visibility='Collapsed'; $window.Height=378
  $ui.Total.Text=' / —'; $ui.Fill.Width=0; $ui.Context.Text='Planning enregistré · recalcul en cours…'
  $ui.Context.ToolTip=$null
 } catch {
  $ui.Context.Text='Enregistrement impossible · réessaie dans un instant.'
  $ui.Context.ToolTip=$_.Exception.Message
 } finally {
  if (Test-Path -LiteralPath $tempConfig) { Remove-Item -LiteralPath $tempConfig -ErrorAction SilentlyContinue }
 }
})
function Format-Points($value) { return ([double]$value).ToString('0.#',[Globalization.CultureInfo]::GetCultureInfo('fr-FR')) }
function Get-PlanningBalance($s) {
 $zone=[TimeZoneInfo]::FindSystemTimeZoneById('Romance Standard Time')
 $first=[TimeZoneInfo]::ConvertTime([DateTimeOffset]::FromUnixTimeSeconds([long]$s.reset-604800),$zone).Date
 $today=[TimeZoneInfo]::ConvertTime([DateTimeOffset]::FromUnixTimeSeconds([long]$s.updated),$zone).Date
 $count=0
 for ($date=$first; $date -le $today; $date=$date.AddDays(1)) {
  if ($s.workdays -contains (([int]$date.DayOfWeek+6)%7)) { $count++ }
 }
 $unlocked=[Math]::Min(100.0,$count*[double]$s.standard_cap)
 return [Math]::Min([double]$s.remaining,[Math]::Max(0.0,$unlocked-[double]$s.used))
}
function Show-State($s) {
 $epoch=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
 $fresh=$s.ok -and $s.updated -and ($epoch-$s.updated -le 150) -and ($s.reset -gt $epoch)
 if ($null -ne $script:pendingDays) {
  if (($s.workdays -join ',') -eq $script:pendingDays) { $script:pendingDays=$null } else { return }
 }
 $ui.UsageLabel.Text="Utilisé aujourd’hui"
 $ui.GlobalRemaining.Text=if ($fresh) { ([double]$s.remaining).ToString('0.############',[Globalization.CultureInfo]::GetCultureInfo('fr-FR'))+' / 100 %' } else { '— / 100 %' }
 $ui.Date.Text=$s.day
 if ($null -ne $s.standard_cap) { $ui.Daily.Text="$(Format-Points $s.standard_cap) %" }
 if ($s.updated) {
  $ui.Weekly.Text="Quota hebdomadaire : $(Format-Points $s.remaining) % restants"
  $ui.Reset.Text="Reset : $($s.reset_label) · Paris"
 }
 if (-not $fresh) {
  $ui.Used.Text='—'; $ui.Total.Text=' / —'; $ui.Bonus.Text='—'; $ui.Fill.Width=0
  $ui.Used.Foreground='#AFBBC8'; $ui.ConnectionDot.Fill='#F0CA8D'
  $ui.Context.Text='Données indisponibles · nouvelle tentative automatique'
  $ui.Context.ToolTip=$s.error; $ui.Status.Text='Hors ligne'; return
 }
 $ui.Context.ToolTip=$null
 $knownBonus=[Math]::Abs($s.opening_bonus_low-$s.opening_bonus_high) -lt 0.000001
 $knownToday=-not $s.uncertain
 $ui.Used.Text=if ($knownToday) { "$(Format-Points $s.today_low) %" } else { "≥ $(Format-Points $s.today_low) %" }
 $ui.Used.FontSize=if ($ui.Used.Text.Length -gt 7) { 36 } else { 42 }
 $ui.Bonus.Text=if ([Math]::Abs($s.bonus_low-$s.bonus_high) -lt 0.000001) { "+$(Format-Points $s.bonus_low) %" } else { '—' }
 $ui.ConnectionDot.Fill='#6DE0B9'
 $ui.Used.Foreground='#6DE0B9'; $ui.Fill.Background='#6DE0B9'
 if ($knownBonus -and $knownToday) {
  $total=[Math]::Min($s.cap+$s.opening_bonus_low,$s.remaining+$s.today_low)
  $ui.Total.Text=" / $(Format-Points $total) %"
  $fraction=if ($total -gt 0) { [Math]::Min(1.0,[double]$s.today_low/[double]$total) } else { 0 }
  $ui.Fill.Width=312*$fraction
  if ($s.available -le 0) { $ui.Used.Foreground='#F19D94'; $ui.Fill.Background='#F19D94'; $ui.Context.Text='Budget disponible épuisé pour ce jour' }
  elseif ($fraction -ge .8) { $ui.Used.Foreground='#F0CA8D'; $ui.Fill.Background='#F0CA8D'; $ui.Context.Text='Bientôt la limite du jour · bonus inclus' }
  else { $ui.Context.Text=if ($s.working_today) { 'Budget total du jour, bonus inclus' } else { 'Jour de repos · utilisation du bonus uniquement' } }
 } else {
  $planned=Get-PlanningBalance $s
  $plannedBonus=[Math]::Max(0.0,$planned-[double]$s.cap)
  $ui.UsageLabel.Text="Disponible aujourd’hui"
  $ui.Used.Text="$(Format-Points $planned) %"
  $ui.Total.Text=''
  $ui.Bonus.Text="+$(Format-Points $plannedBonus) %"
  $ui.Fill.Width=312*[Math]::Min(1.0,$planned/[Math]::Max(0.000001,[double]$s.cap+$plannedBonus))
  $ui.Context.Text='Solde du planning − consommation globale'
  $ui.Context.ToolTip='Budget débloqué depuis le reset selon les jours cochés, moins toute la consommation du cycle. Le détail consommé depuis minuit reste inconnu.'
 }
 $time=[DateTimeOffset]::FromUnixTimeSeconds([long]$s.updated).ToLocalTime().ToString('HH:mm')
 $ui.Status.Text="Mis à jour à $time · toutes les minutes"
}
function Update-Widget {
 $file=Join-Path $dataDir 'status.json'
 if (Test-Path -LiteralPath $file) { try { $s=Get-Content -LiteralPath $file -Raw -Encoding UTF8|ConvertFrom-Json } catch { return }; Show-State $s }
}
$timer=[Windows.Threading.DispatcherTimer]::new(); $timer.Interval=[TimeSpan]::FromSeconds(2); $timer.Add_Tick({ Update-Widget })
if (-not $Preview) {
 $exe=Join-Path $PSScriptRoot 'bin\BudgetMonitor.exe'
 if (-not (Test-Path -LiteralPath $exe)) { throw 'BudgetMonitor.exe absent.' }
 Start-Process -FilePath $exe -ArgumentList @('--data',('"'+$dataDir+'"'),'--parent',$PID) -WindowStyle Hidden | Out-Null
}
$window.Add_Closed({ $timer.Stop(); if (-not $Preview) { @{left=$window.Left;top=$window.Top;pin=$window.Topmost}|ConvertTo-Json|Set-Content -LiteralPath $settings -Encoding UTF8 } })
try {
 Update-Widget
 if ($Preview) {
  if ($PreviewState -ne 'live') {
   $demo=[pscustomobject]@{ok=$true;updated=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds();reset=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()+86400;standard_cap=15;cap=15;day='10/09';remaining=80;used=20;today_low=5;uncertain=$false;opening_bonus_low=2;opening_bonus_high=2;bonus_low=2;bonus_high=2;available=12;working_today=$true;reset_label='16/09 à 08:36';workdays=@(0,1,2,3,4,5,6)}
   if ($PreviewState -eq 'bonus') { $demo.today_low=16; $demo.bonus_low=1; $demo.bonus_high=1; $demo.available=1 }
   if ($PreviewState -eq 'partial') { $demo.uncertain=$true; $demo.today_low=1; $demo.opening_bonus_high=15; $demo.bonus_high=15 }
   if ($PreviewState -eq 'offline') { $demo.ok=$false }
   Show-State $demo
   if ($PreviewState -eq 'settings') { $ui.SettingsPanel.Visibility='Visible'; $window.Height=603 }
  }
  $window.Show(); $window.UpdateLayout()
  $bitmap=[Windows.Media.Imaging.RenderTargetBitmap]::new([int]$window.ActualWidth,[int]$window.ActualHeight,96,96,[Windows.Media.PixelFormats]::Pbgra32); $bitmap.Render($window)
  $encoder=[Windows.Media.Imaging.PngBitmapEncoder]::new(); $encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
  $stream=[IO.File]::Create((Join-Path $PSScriptRoot ("preview-$PreviewState.png"))); $encoder.Save($stream); $stream.Dispose(); $window.Close()
 } else { $timer.Start(); $window.ShowDialog()|Out-Null }
} finally { $timer.Stop(); if ($ownsMutex) { $mutex.ReleaseMutex() }; $mutex.Dispose() }
