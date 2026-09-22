param([switch]$Preview, [ValidateSet('live','normal','bonus','partial','offline','settings')][string]$PreviewState='live', [ValidateSet('','fr','en')][string]$Language='', [ValidateSet('codex','spark')][string]$PreviewModel='codex')
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
$dataDir = Join-Path $PSScriptRoot 'data'
[IO.Directory]::CreateDirectory($dataDir) | Out-Null
. (Join-Path $PSScriptRoot 'i18n.ps1')
$script:language=Get-Language $Language
$script:sourceSelection='auto'
try { $savedSource=(Get-Content (Join-Path $dataDir 'source.json') -Raw -Encoding UTF8|ConvertFrom-Json).source; if ($savedSource -in @('auto','windows') -or $savedSource -like 'wsl:*') { $script:sourceSelection=$savedSource } } catch {}
$script:sourceOptions=@('auto','windows')
$script:loadingSources=$false
$script:model='codex'
try { $savedModel=(Get-Content (Join-Path $dataDir 'model.json') -Raw -Encoding UTF8 | ConvertFrom-Json).model; if ($savedModel -in @('codex','spark')) { $script:model=$savedModel } } catch {}
if ($Preview) { $script:model=$PreviewModel }
$ownsMutex = $false
$mutex = [Threading.Mutex]::new($true, 'Local\CodexBudgetWidget_v1', [ref]$ownsMutex)
if (-not $ownsMutex -and -not $Preview) { $mutex.Dispose(); exit }
[xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
 xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Title="Budget Codex"
 Width="360" Height="565" WindowStyle="None" AllowsTransparency="True" Background="Transparent"
 ResizeMode="NoResize" Topmost="True" WindowStartupLocation="Manual"
 FontFamily="Segoe UI" FontSize="12" Foreground="#F4F7FA" UseLayoutRounding="True">
 <Window.Resources>
  <Style x:Key="SourceSelector" TargetType="ComboBox">
   <Setter Property="Foreground" Value="#F4F7FA"/>
   <Setter Property="ItemContainerStyle"><Setter.Value><Style TargetType="ComboBoxItem">
    <Setter Property="Padding" Value="10,7"/><Setter Property="Foreground" Value="#F4F7FA"/>
    <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="ComboBoxItem"><Border x:Name="Row" Background="#22282F" Padding="{TemplateBinding Padding}"><ContentPresenter/></Border><ControlTemplate.Triggers><Trigger Property="IsHighlighted" Value="True"><Setter TargetName="Row" Property="Background" Value="#38434D"/></Trigger><Trigger Property="IsSelected" Value="True"><Setter Property="Foreground" Value="#6DE0B9"/></Trigger></ControlTemplate.Triggers></ControlTemplate></Setter.Value></Setter>
   </Style></Setter.Value></Setter>
   <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="ComboBox">
    <Grid>
     <ToggleButton IsChecked="{Binding IsDropDownOpen, RelativeSource={RelativeSource TemplatedParent}, Mode=TwoWay}" Focusable="False" ClickMode="Press">
      <ToggleButton.Template><ControlTemplate TargetType="ToggleButton"><Border x:Name="Surface" Background="#22282F" BorderBrush="#46515E" BorderThickness="1" CornerRadius="5"><Path HorizontalAlignment="Right" VerticalAlignment="Center" Margin="0,0,11,0" Stroke="#AFBBC8" StrokeThickness="1.5" Data="M 0,0 L 4,4 L 8,0"/></Border><ControlTemplate.Triggers><Trigger Property="IsMouseOver" Value="True"><Setter TargetName="Surface" Property="BorderBrush" Value="#6DE0B9"/></Trigger></ControlTemplate.Triggers></ControlTemplate></ToggleButton.Template>
     </ToggleButton>
     <Border x:Name="SourceFocus" CornerRadius="5" BorderBrush="#6DE0B9" BorderThickness="1" Visibility="Hidden" IsHitTestVisible="False"/>
     <ContentPresenter Content="{TemplateBinding SelectionBoxItem}" ClipToBounds="True" Margin="10,0,28,0" VerticalAlignment="Center" IsHitTestVisible="False"/>
     <Popup x:Name="PART_Popup" IsOpen="{TemplateBinding IsDropDownOpen}" Placement="Bottom" AllowsTransparency="True" Focusable="False">
      <Border Background="#22282F" BorderBrush="#46515E" BorderThickness="1" CornerRadius="5" MinWidth="{Binding ActualWidth, RelativeSource={RelativeSource TemplatedParent}}"><ScrollViewer MaxHeight="180"><ItemsPresenter KeyboardNavigation.DirectionalNavigation="Contained"/></ScrollViewer></Border>
     </Popup>
    </Grid>
    <ControlTemplate.Triggers><Trigger Property="IsKeyboardFocusWithin" Value="True"><Setter TargetName="SourceFocus" Property="Visibility" Value="Visible"/></Trigger><Trigger Property="IsDropDownOpen" Value="True"><Setter TargetName="SourceFocus" Property="Visibility" Value="Visible"/></Trigger><Trigger Property="IsEnabled" Value="False"><Setter Property="Opacity" Value="0.45"/></Trigger></ControlTemplate.Triggers>
   </ControlTemplate></Setter.Value></Setter>
  </Style>
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
  <ScrollViewer VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled">
  <StackPanel>
   <Grid x:Name="DragArea" Height="53" Background="Transparent" Margin="17,0,10,0">
    <Grid.ColumnDefinitions><ColumnDefinition/><ColumnDefinition Width="64"/><ColumnDefinition Width="32"/><ColumnDefinition Width="32"/><ColumnDefinition Width="32"/></Grid.ColumnDefinitions>
    <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
     <Ellipse x:Name="ConnectionDot" Width="6" Height="6" Fill="#AFBBC8" Margin="0,0,9,0"/>
     <TextBlock Text="Codex" FontWeight="SemiBold" FontSize="14"/>
     <TextBlock Text=" / Budget" Foreground="#AFBBC8" FontSize="14"/>
    </StackPanel>
    <StackPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center">
     <Button x:Name="LangFR" Content="FR" Width="29" Height="27" FontSize="10" FontWeight="SemiBold" Padding="2" Style="{StaticResource ControlButton}" ToolTip="Français" AutomationProperties.Name="Français"/>
     <Button x:Name="LangEN" Content="EN" Width="29" Height="27" FontSize="10" FontWeight="SemiBold" Padding="2" Style="{StaticResource ControlButton}" ToolTip="English" AutomationProperties.Name="English"/>
    </StackPanel>
    <Button x:Name="SettingsButton" Grid.Column="2" Style="{StaticResource ControlButton}" Height="30" Padding="6" ToolTip="Réglages" AutomationProperties.Name="Réglages">
     <Path Width="16" Height="16" Stretch="Uniform" Stroke="{Binding Foreground, RelativeSource={RelativeSource AncestorType=Button}}" StrokeThickness="1.5" Data="M 1,4 L 15,4 M 1,12 L 15,12 M 5,1 L 5,7 M 11,9 L 11,15"/>
    </Button>
    <Button x:Name="Minimize" Grid.Column="3" Style="{StaticResource ControlButton}" Height="30" Padding="6" ToolTip="Réduire" AutomationProperties.Name="Réduire">
     <Path Width="12" Height="12" Stroke="{Binding Foreground, RelativeSource={RelativeSource AncestorType=Button}}" StrokeThickness="1.5" Data="M 1,7 L 11,7"/>
    </Button>
    <Button x:Name="Close" Grid.Column="4" Style="{StaticResource ControlButton}" Height="30" Padding="6" ToolTip="Fermer" AutomationProperties.Name="Fermer">
     <Path Width="12" Height="12" Stroke="{Binding Foreground, RelativeSource={RelativeSource AncestorType=Button}}" StrokeThickness="1.5" Data="M 2,2 L 10,10 M 10,2 L 2,10"/>
    </Button>
   </Grid>
   <Border Margin="22,0,22,8" Height="34" Background="#22282F" CornerRadius="7" Padding="3">
    <UniformGrid Columns="2">
     <Button x:Name="ModelCodex" Content="Codex" Style="{StaticResource ControlButton}" FontWeight="SemiBold" Padding="4,2" AutomationProperties.Name="Codex"/>
     <Button x:Name="ModelSpark" Content="Spark" Style="{StaticResource ControlButton}" FontWeight="SemiBold" Padding="4,2" ToolTip="GPT-5.3-Codex-Spark" AutomationProperties.Name="GPT-5.3-Codex-Spark"/>
    </UniformGrid>
   </Border>
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
     <StackPanel><TextBlock x:Name="DailyLabel" Text="Par jour" Foreground="#AFBBC8"/><TextBlock x:Name="Daily" Text="—" FontSize="24" FontWeight="SemiBold" Margin="0,2,0,0"/></StackPanel>
     <Border Grid.Column="1" Background="#303842" Margin="0,2,0,2"/>
     <StackPanel Grid.Column="2" Margin="20,0,0,0"><TextBlock x:Name="BonusLabel" Text="Bonus" Foreground="#AFBBC8"/><TextBlock x:Name="Bonus" Text="—" FontSize="24" FontWeight="SemiBold" Foreground="#F0CA8D" Margin="0,2,0,0" ToolTip="Bonus reporté encore disponible. Le total du jour inclut le bonus du début de journée."/></StackPanel>
    </Grid>
   </StackPanel>
   <Border Background="#20272E" CornerRadius="8" Margin="22,12,22,0" Padding="12,9">
    <StackPanel>
     <DockPanel><TextBlock x:Name="TomorrowLabel" Text="Demain" Foreground="#AFBBC8" VerticalAlignment="Center"/><TextBlock x:Name="TomorrowValue" Text="—" FontSize="22" FontWeight="SemiBold" HorizontalAlignment="Right" Foreground="#6DE0B9"/></DockPanel>
     <TextBlock x:Name="TomorrowHint" FontSize="10" Foreground="#AFBBC8" Margin="0,3,0,0" TextWrapping="Wrap"/>
     <Border Height="1" Background="#303842" Margin="0,8,0,7"/>
     <TextBlock x:Name="WeeklyAverage" FontSize="11" Foreground="#AFBBC8" TextWrapping="Wrap"/>
     <DockPanel Margin="0,5,0,0"><TextBlock x:Name="ProjectionLabel" FontSize="11" Foreground="#AFBBC8" VerticalAlignment="Center"/><TextBlock x:Name="ProjectionValue" FontSize="18" FontWeight="SemiBold" Foreground="#F0CA8D" HorizontalAlignment="Right"/></DockPanel>
    </StackPanel>
   </Border>
   <Border BorderBrush="#303842" BorderThickness="0,1,0,0" Margin="22,12,22,0" Padding="0,9,0,0">
    <DockPanel><TextBlock x:Name="GlobalLabel" Text="Quota global restant" Foreground="#AFBBC8" VerticalAlignment="Center"/><TextBlock x:Name="GlobalRemaining" Text="— / 100 %" HorizontalAlignment="Right" FontSize="18" FontWeight="SemiBold"/></DockPanel>
   </Border>
   <Border x:Name="ShortPanel" Visibility="Collapsed" Margin="22,12,22,0" Padding="0,10,0,0" BorderBrush="#303842" BorderThickness="0,1,0,0" Height="100">
    <StackPanel>
     <DockPanel><TextBlock x:Name="ShortLabel" Text="Spark · 5 h" Foreground="#AFBBC8" VerticalAlignment="Center"/><TextBlock x:Name="ShortValue" Text="—" FontSize="22" FontWeight="SemiBold" HorizontalAlignment="Right" Foreground="#AFA6FF"/></DockPanel>
     <Grid Height="5" Margin="0,8,0,8" ClipToBounds="True"><Border Background="#303842" CornerRadius="2"/><Border x:Name="ShortFill" Width="0" HorizontalAlignment="Left" Background="#AFA6FF" CornerRadius="2"/></Grid>
     <TextBlock x:Name="ShortReset" Text="—" FontSize="11" Foreground="#AFBBC8"/>
    </StackPanel>
   </Border>
   <Grid Margin="17,9,15,7" Height="25">
    <TextBlock x:Name="Status" Text="Connexion…" Foreground="#AFBBC8" FontSize="10" VerticalAlignment="Center"/>
    <Button x:Name="Refresh" Content="Actualiser" Style="{StaticResource ControlButton}" HorizontalAlignment="Right" FontSize="10" Padding="6,2"/>
   </Grid>
   <Border x:Name="SettingsPanel" Visibility="Collapsed" BorderBrush="#303842" BorderThickness="0,1,0,0" Padding="20,15,20,16">
    <StackPanel>
     <TextBlock x:Name="SourceLabel" Text="Source des quotas" FontWeight="SemiBold" Margin="0,0,0,8"/>
     <ComboBox x:Name="SourceChoice" Height="30" Margin="0,0,0,6" Style="{StaticResource SourceSelector}" AutomationProperties.Name="Quota source"/>
     <TextBlock x:Name="SourceHint" Text="Choix enregistré automatiquement" Foreground="#AFBBC8" FontSize="10" Margin="0,0,0,14"/>
     <DockPanel><TextBlock x:Name="DaysLabel" Text="Jours travaillés" FontWeight="SemiBold" VerticalAlignment="Center"/><Button x:Name="SaveDays" Content="Appliquer" HorizontalAlignment="Right" Style="{StaticResource ControlButton}" Background="#303842"/></DockPanel>
     <UniformGrid x:Name="Workdays" Columns="7" Margin="0,12,0,16"/>
     <CheckBox x:Name="Pin" Content="Toujours au premier plan" IsChecked="True" Foreground="#F4F7FA"/>
     <TextBlock x:Name="Weekly" Text="Quota hebdomadaire : —" Foreground="#AFBBC8" Margin="0,15,0,4"/>
     <TextBlock x:Name="Reset" Text="Reset : —" Foreground="#AFBBC8"/>
     <Border BorderBrush="#303842" BorderThickness="0,1,0,0" Margin="0,16,0,0" Padding="0,12,0,0">
      <StackPanel>
       <DockPanel><TextBlock x:Name="DiagnosticLabel" Text="Diagnostic" FontWeight="SemiBold" VerticalAlignment="Center"/><Button x:Name="CopyDiagnostic" Content="Copier le rapport" Style="{StaticResource ControlButton}" HorizontalAlignment="Right" Background="#22282F" FontSize="10"/></DockPanel>
       <TextBlock x:Name="DiagnosticHint" Text="À joindre à votre signalement de bug" Foreground="#AFBBC8" FontSize="10" Margin="0,5,0,8"/>
       <Border Background="#12161A" BorderBrush="#38414B" BorderThickness="1" CornerRadius="6" Padding="8">
        <TextBox x:Name="DiagnosticConsole" IsReadOnly="True" Height="128" Background="Transparent" BorderThickness="0" Foreground="#C8D2DC" FontFamily="Consolas" FontSize="10" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled" SelectionBrush="#41695C" AutomationProperties.Name="Diagnostic"/>
       </Border>
      </StackPanel>
     </Border>
    </StackPanel>
   </Border>
  </StackPanel>
  </ScrollViewer>
 </Border>
</Window>
'@
$window = [Windows.Markup.XamlReader]::Load([Xml.XmlNodeReader]::new($xaml))
$ui = @{}
'WeeklyAverage','ProjectionLabel','ProjectionValue','TomorrowLabel','TomorrowValue','TomorrowHint','DiagnosticLabel','DiagnosticHint','DiagnosticConsole','CopyDiagnostic','SourceLabel','SourceChoice','SourceHint','ModelCodex','ModelSpark','ShortPanel','ShortLabel','ShortValue','ShortFill','ShortReset','LangFR','LangEN','DailyLabel','BonusLabel','GlobalLabel','DaysLabel','UsageLabel','GlobalRemaining','DragArea','ConnectionDot','SettingsButton','Minimize','Close','Date','Used','Total','Track','Fill','Context','Daily','Bonus','Status','Refresh','SettingsPanel','SaveDays','Workdays','Pin','Weekly','Reset' | ForEach-Object { $ui[$_] = $window.FindName($_) }
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
  $ui.SettingsPanel.Visibility = 'Visible'; Update-Diagnostic; Resize-Widget
  Resize-Widget
 } else { $ui.SettingsPanel.Visibility = 'Collapsed'; Resize-Widget }
})
$window.Add_KeyDown({ if ($_.Key -eq 'Escape' -and $ui.SettingsPanel.Visibility -eq 'Visible') { $ui.SettingsPanel.Visibility='Collapsed'; Resize-Widget; $_.Handled=$true } })
$ui.Pin.Add_Click({ $window.Topmost = [bool]$ui.Pin.IsChecked })
$ui.Refresh.Add_Click({ try { [IO.File]::WriteAllText((Join-Path $dataDir 'refresh'), '') } catch { $ui.Context.Text=(T 'Données indisponibles · nouvelle tentative automatique') } })
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
 if ($selected.Count -eq 0) { $ui.Context.Text=(T (T "Choisis au moins un jour travaillé.")); return }
 if (($selected -join ',') -eq ($chosenDays -join ',')) {
  $ui.SettingsPanel.Visibility='Collapsed'; Resize-Widget
  return
 }
 $tempConfig=$workdaysFile+'.'+[Guid]::NewGuid().ToString('N')+'.tmp'
 try {
  $changes=@()
  if (Test-Path -LiteralPath $workdaysFile) {
   $previous=Get-Content -LiteralPath $workdaysFile -Raw -Encoding UTF8 | ConvertFrom-Json
   if ($previous.changes) { $changes=@($previous.changes) }
  }
  if ($changes.Count -eq 0) { $changes=@(@{at=0;workdays=@($chosenDays)}) }
  $changes+=@{at=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds();workdays=$selected}
  [IO.File]::WriteAllText($tempConfig,(@{workdays=$selected;changes=$changes}|ConvertTo-Json -Depth 6),[Text.UTF8Encoding]::new($false))
  # An explicit backup path avoids PowerShell 5.1 converting $null to an empty path.
  if (Test-Path -LiteralPath $workdaysFile) { [IO.File]::Replace($tempConfig,$workdaysFile,$workdaysFile+'.bak') } else { [IO.File]::Move($tempConfig,$workdaysFile) }
  $script:chosenDays=$selected
  $script:pendingDays = $selected -join ','
  [IO.File]::WriteAllText((Join-Path $dataDir 'refresh'),'')
  $ui.SettingsPanel.Visibility='Collapsed'; Resize-Widget
  $ui.Total.Text=' / —'; $ui.Fill.Width=0; $ui.Context.Text=(T (T "Planning enregistré · recalcul en cours…"))
  $ui.TomorrowValue.Text='—'; $ui.TomorrowHint.Text=''; $ui.WeeklyAverage.Text='—'; $ui.ProjectionValue.Text='—'; $ui.ProjectionLabel.Text=(T 'Demain à ce rythme')
 $ui.Context.ToolTip=$null
 } catch {
  $ui.Context.Text=(T (T "Enregistrement impossible · réessaie dans un instant."))
  $ui.Context.ToolTip=(T "Enregistrement impossible · réessaie dans un instant.")
 } finally {
  if (Test-Path -LiteralPath $tempConfig) { Remove-Item -LiteralPath $tempConfig -ErrorAction SilentlyContinue }
 }
})
function Format-Points($value) { return ([double]$value).ToString('0.#',(Get-DisplayCulture)) }
function Get-PlanningBalance($s, [switch]$Signed) {
 if ($null -ne $s.planning_balance) {
  if ($Signed) { return [double]$s.planning_balance }
  return [Math]::Min([double]$s.remaining,[Math]::Max(0.0,[double]$s.planning_balance))
 }
 [TimeZoneInfo]::ClearCachedData()
 $zone=[TimeZoneInfo]::Local
 $first=[TimeZoneInfo]::ConvertTime([DateTimeOffset]::FromUnixTimeSeconds([long]$s.reset-604800),$zone).Date
 $today=[TimeZoneInfo]::ConvertTime([DateTimeOffset]::FromUnixTimeSeconds([long]$s.updated),$zone).Date
 $count=0
 for ($date=$first; $date -le $today; $date=$date.AddDays(1)) {
  if ($s.workdays -contains (([int]$date.DayOfWeek+6)%7)) { $count++ }
 }
 $unlocked=[Math]::Min(100.0,$count*[double]$s.standard_cap)
 if ($Signed) { return $unlocked-[double]$s.used }
 return [Math]::Min([double]$s.remaining,[Math]::Max(0.0,$unlocked-[double]$s.used))
}
function Show-Carry([double]$value) {
 $negative=$value -lt -0.000001
 $ui.BonusLabel.Text=if ($negative) { (T 'Malus') } else { 'Bonus' }
 $ui.Bonus.Foreground=if ($negative) { '#F19D94' } else { '#F0CA8D' }
 $ui.Bonus.Text=if ($negative) { "$(Format-Points $value) %" } else { "+$(Format-Points ([Math]::Max(0,$value))) %" }
 $ui.Bonus.ToolTip=(T "Le report positif augmente le budget ; le malus le réduit jusqu’au reset hebdomadaire.")
}
function Show-State($s) {
 $ui.Track.Visibility='Visible'
 $ui.Used.ToolTip=$null
 Show-Carry 0
 $script:lastState=$s
 $ui.Status.ToolTip=$s.source
 Show-Short $s.short
 $epoch=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
 $fresh=$s.ok -and $s.updated -and ($epoch-$s.updated -le 150) -and ($s.reset -gt $epoch)
 if ($null -ne $script:pendingDays) {
  if (($s.workdays -join ',') -eq $script:pendingDays) { $script:pendingDays=$null } else { return }
 }
 $ui.UsageLabel.Text=(T "Utilisé aujourd’hui")
 $ui.GlobalRemaining.Text=if ($fresh) { ([double]$s.remaining).ToString('0.############',(Get-DisplayCulture))+' / 100 %' } else { '— / 100 %' }
 $ui.Date.Text=$s.day
 if (-not $fresh) { $ui.Daily.Text='—'; $ui.Weekly.Text=(T 'Quota hebdomadaire : —'); $ui.Reset.Text=(T 'Reset : —') }
 if ($null -ne $s.standard_cap) { $ui.Daily.Text="$(Format-Points $s.standard_cap) %" }
 if ($s.updated -and $s.reset) {
  $ui.Weekly.Text=(T "Quota hebdomadaire : {0} % restants") -f (Format-Points $s.remaining)
  [TimeZoneInfo]::ClearCachedData()
  $localReset=[TimeZoneInfo]::ConvertTime([DateTimeOffset]::FromUnixTimeSeconds([long]$s.reset),[TimeZoneInfo]::Local)
  $ui.Reset.Text=(T "Reset : {0} · heure locale") -f $localReset.ToString("dd/MM HH:mm")
  $ui.Reset.ToolTip=[TimeZoneInfo]::Local.DisplayName
 }
 if (-not $fresh) {
  $ui.TomorrowLabel.Text=(T 'Demain'); $ui.TomorrowValue.Text='—'; $ui.TomorrowHint.Text=''; $ui.WeeklyAverage.Text='—'; $ui.ProjectionValue.Text='—'; $ui.ProjectionLabel.Text=(T 'Demain à ce rythme')
  $ui.Used.Text='—'; $ui.Total.Text=' / —'; $ui.Bonus.Text='—'; $ui.Fill.Width=0
  $ui.Used.Foreground='#AFBBC8'; $ui.ConnectionDot.Fill='#F0CA8D'
  $message=switch ($s.error_code) {
   'codex_missing' { 'Codex absent · Windows ou WSL' }
   'wsl_missing' { 'Codex introuvable dans la distribution choisie' }
   'invalid_source' { 'Choisissez une source dans les réglages' }
   'wsl_login_required' { 'Dans WSL : lancez codex login' }
   'login_required' { 'Compte déconnecté · lancez codex login' }
   'api_key' { 'Clé API · quota ChatGPT indisponible' }
   'read_failed' { 'Lecture impossible · vérifiez Codex et la connexion' }
   default { 'Données indisponibles · nouvelle tentative automatique' }
  }
  $ui.Context.Text=(T $message)
  $ui.Context.ToolTip=(T $message); $ui.Status.Text=(T (T "Hors ligne")); return
 }
 $ui.WeeklyAverage.Text=if ($null -ne $s.average_usage) { (T 'Moyenne semaine : {0} % / jour travaillé') -f (Format-Points $s.average_usage) } else { (T 'Moyenne : une journée travaillée nécessaire') }
 $ui.ProjectionLabel.Text=(T 'Demain à ce rythme')
 $ui.ProjectionValue.Text=if ($null -ne $s.projected_tomorrow) { "≈ $(Format-Points $s.projected_tomorrow) %" } else { '—' }
 $ui.ProjectionValue.ToolTip=(T "Estimation du budget disponible demain si le rythme moyen continue jusqu’à ce soir. Le jour en cours est pondéré par le temps écoulé ; les jours de repos ne créent pas de consommation prévue.")
 $ui.TomorrowLabel.Text=if ($s.tomorrow_working) { (T 'Demain') } else { (T 'Demain · repos') }
 $ui.TomorrowValue.Text=if ($null -ne $s.tomorrow_available) { "$(Format-Points $s.tomorrow_available) %" } else { '—' }
 $ui.TomorrowHint.Text=if ($s.tomorrow_reset) { (T 'Reset avant demain · nouveau quota à confirmer') } else { (T "Si vous ne consommez plus aujourd’hui") }
 $ui.Context.ToolTip=$null
 $knownBonus=[Math]::Abs($s.opening_bonus_low-$s.opening_bonus_high) -lt 0.000001
 $knownToday=-not $s.uncertain
 $ui.Used.Text=if ($knownToday) { "$(Format-Points $s.today_low) %" } else { "≥ $(Format-Points $s.today_low) %" }
 $ui.Used.FontSize=if ($ui.Used.Text.Length -gt 7) { 36 } else { 42 }
 $carryLow=if ($null -ne $s.carry_low) { $s.carry_low } else { $s.bonus_low }
 $carryHigh=if ($null -ne $s.carry_high) { $s.carry_high } else { $s.bonus_high }
 if ([Math]::Abs($carryLow-$carryHigh) -lt 0.000001) { Show-Carry $carryLow } else { $ui.Bonus.Text='—' }
 $ui.ConnectionDot.Fill='#6DE0B9'
 $ui.Used.Foreground='#6DE0B9'; $ui.Fill.Background='#6DE0B9'
 if ($knownBonus -and $knownToday) {
  $total=[Math]::Max(0.0,[Math]::Min($s.cap+$s.opening_bonus_low,$s.remaining+$s.today_low))
  $ui.Total.Text=" / $(Format-Points $total) %"
  $fraction=if ($total -gt 0) { [Math]::Min(1.0,[double]$s.today_low/[double]$total) } else { 0 }
  $ui.Fill.Width=312*$fraction
  if ($s.available -le 0) { $ui.Used.Foreground='#F19D94'; $ui.Fill.Background='#F19D94'; $ui.Context.Text=(T (T "Budget disponible épuisé pour ce jour")) }
  elseif ($fraction -ge .8) { $ui.Used.Foreground='#F0CA8D'; $ui.Fill.Background='#F0CA8D'; $ui.Context.Text=(T (T "Bientôt la limite du jour · bonus inclus")) }
  else { $ui.Context.Text=if ($s.working_today) { (T (T "Budget total du jour, bonus inclus")) } else { (T (T "Jour de repos · utilisation du bonus uniquement")) } }
  if ($s.available -gt 0 -and $s.opening_bonus_low -lt 0) { $ui.Context.Text=(T "Budget du jour réduit par le malus reporté") }
 } else {
  $planned=Get-PlanningBalance $s
  $plannedBonus=[Math]::Max(0.0,$planned-[double]$s.cap)
  $ui.UsageLabel.Text=(T "Disponible aujourd’hui")
  $ui.Used.Text="$(Format-Points $planned) %"
  $ui.Total.Text=''
  $signed=Get-PlanningBalance $s -Signed
  if ($signed -lt 0) { Show-Carry $signed } else { Show-Carry $plannedBonus }
  $ui.Fill.Width=312*[Math]::Min(1.0,$planned/[Math]::Max(0.000001,[double]$s.cap+$plannedBonus))
  $ui.Context.Text=(T (T "Solde du planning − consommation globale"))
  if ($planned -le 0) {
   $ui.Used.FontSize=23
   $ui.Used.Foreground='#F0CA8D'
   if ([double]$s.remaining -le 0) {
    $ui.Used.Text=(T 'Quota hebdomadaire')+[Environment]::NewLine+(T 'épuisé')
    $ui.Used.Foreground='#F19D94'
    $ui.Context.Text=(T 'En attente du renouvellement hebdomadaire')
   } elseif (-not $s.working_today) {
    $ui.Used.Text=(T 'Jour de repos')
    $ui.Context.Text=(T 'Il reste {0} % sur la semaine') -f (Format-Points $s.remaining)
   } else {
    $ui.Used.Text=(T 'Budget du jour')+[Environment]::NewLine+(T 'épuisé')
    $ui.Context.Text=(T 'Il reste {0} % sur la semaine') -f (Format-Points $s.remaining)
   }
  }
  $ui.Context.ToolTip=(T (T "Budget débloqué depuis le reset selon les jours cochés, moins toute la consommation du cycle. Le détail consommé depuis minuit reste inconnu."))
 }
 if ($null -ne $s.carry_low -and $s.carry_low -lt 0 -and [Math]::Abs($s.carry_low-$s.carry_high) -lt 0.000001) { Show-Carry $s.carry_low }
 if ($null -ne $s.remaining_plan) {
  $plan=$s.remaining_plan
  $ui.UsageLabel.Text=(T "Disponible aujourd’hui")
  $ui.Used.Text="$(Format-Points $plan.available) %"; $ui.Used.FontSize=42; $ui.Total.Text=''
  $ui.Used.Foreground='#6DE0B9'; $ui.Fill.Background='#6DE0B9'
  $ui.Fill.Width=312*[Math]::Min(1.0,[double]$plan.available/[Math]::Max(0.000001,[double]$s.remaining))
  $ui.Daily.Text="$(Format-Points $plan.daily) %"
  $ui.BonusLabel.Text=(T 'Jours restants'); $ui.Bonus.Text=if ($null -ne $plan.day_equivalents -and [Math]::Abs($plan.day_equivalents-$plan.days) -gt 0.000001) { (Format-Points $plan.day_equivalents) } else { [string]$plan.days }; $ui.Bonus.Foreground='#AFBBC8'
  $ui.Bonus.ToolTip=(T "Jours travaillés restants avant le reset, aujourd’hui inclus")
  $ui.Context.Text=if ($plan.working_today) { (T "Quota restant réparti jusqu’au reset") } else { (T 'Jour de repos') }
  $ui.UsageLabel.Text=(T "Aujourd’hui · utilisé / restant")
  $ui.Used.Text=if ($s.uncertain) { "≥ $(Format-Points $s.today_low) %" } else { "$(Format-Points $s.today_low) %" }
  $ui.Total.Text=" / $(Format-Points $plan.available) %"
  $ui.Used.FontSize=if ($ui.Used.Text.Length -gt 7) { 36 } else { 42 }
  $sum=[double]$s.today_low+[double]$plan.available
  $ui.Fill.Width=312*[Math]::Min(1.0,[double]$s.today_low/[Math]::Max(0.000001,$sum))
  $ui.Context.Text=(T "Encore {0} % disponibles aujourd’hui") -f (Format-Points $plan.available)
  if ($s.uncertain) {
   $ui.Used.ToolTip=(T "Consommation minimale observée aujourd’hui ; le relevé du début de journée manque.")
  }
  $ui.Context.ToolTip=(T 'Le quota réel restant est partagé entre les jours travaillés avant le reset. La consommation passée est déjà déduite : aucun malus supplémentaire.')
  if (-not $plan.working_today) {
   $ui.UsageLabel.Text=(T "Utilisé aujourd’hui")
   $ui.Used.Text=if ($s.uncertain) { "≥ $(Format-Points $s.today_low) %" } else { "$(Format-Points $s.today_low) %" }
   $ui.Used.FontSize=if ($ui.Used.Text.Length -gt 7) { 36 } else { 42 }
   $ui.Total.Text=''; $ui.Fill.Width=0; $ui.Track.Visibility='Collapsed'
   $ui.Context.Text=(T 'Jour non travaillé · aucun objectif quotidien')
   $ui.Context.ToolTip=(T 'Votre quota global reste utilisable. La consommation de ce jour est déduite des budgets des prochains jours travaillés.')
  }
  $ui.TomorrowLabel.Text=if ($plan.tomorrow_working) { (T 'Demain') } else { (T 'Demain · repos') }
  $ui.TomorrowValue.Text=if ($null -ne $plan.tomorrow_available) { "$(Format-Points $plan.tomorrow_available) %" } else { '—' }
  $ui.ProjectionValue.Text=if ($null -ne $plan.projected_tomorrow) { "≈ $(Format-Points $plan.projected_tomorrow) %" } else { '—' }
 }
 $time=[DateTimeOffset]::FromUnixTimeSeconds([long]$s.updated).ToLocalTime().ToString('HH:mm')
 $ui.Status.Text=(T "Mis à jour à {0} · toutes les 15 s") -f $time
 if ($script:model -eq 'spark' -and $s.short.ok -and $s.short.reset -gt $epoch -and $s.short.remaining -le 0) {
  $ui.Context.Text=(T "Spark : limite 5 h atteinte · attendre le reset")
 }
}
function Resize-Widget {
 $height=565
 if ($script:model -eq 'spark') { $height+=112 }
 if ($ui.SettingsPanel.Visibility -eq 'Visible') { $height+=535 }
 $height=[Math]::Min($height,[Windows.SystemParameters]::WorkArea.Height)
 $window.Height=$height
 $window.Top=[Math]::Max(0,[Math]::Min($window.Top,[Windows.SystemParameters]::WorkArea.Bottom-$height))
}
function Show-Short($short) {
 $ui.ShortLabel.Text=(T 'Spark · 5 h restantes')
 $ui.ShortValue.Text='—'; $ui.ShortValue.Foreground='#AFA6FF'; $ui.ShortFill.Width=0
 $ui.ShortReset.Text=(T 'Limite 5 h indisponible')
 $epoch=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
 if ($short.ok -and $short.reset -gt $epoch -and ($epoch-$short.updated) -le 150) {
  $ui.ShortValue.Text="$(Format-Points $short.remaining) %"
  if ($short.remaining -le 0) { $ui.ShortValue.Foreground='#F19D94' }
  $ui.ShortFill.Width=312*[double]$short.remaining/100
  $ui.ShortFill.Background=if ($short.remaining -le 0) { '#F19D94' } else { '#AFA6FF' }
  $reset=[DateTimeOffset]::FromUnixTimeSeconds([long]$short.reset).ToLocalTime().ToString('dd/MM HH:mm')
  $ui.ShortReset.Text=(T 'Reset : {0} · heure locale') -f $reset
 }
}
function Set-Model([string]$value,[switch]$Persist) {
 if ($Persist) {
  $file=Join-Path $dataDir 'model.json'; $tmp=$file+'.tmp'
  try { [IO.File]::WriteAllText($tmp,(@{model=$value}|ConvertTo-Json)); if (Test-Path $file) { [IO.File]::Replace($tmp,$file,$file+'.bak') } else { [IO.File]::Move($tmp,$file) } }
  catch { $ui.Context.Text=(T 'Enregistrement impossible · réessaie dans un instant.'); return }
 }
 $script:model=$value
 $ui.ShortPanel.Visibility=if ($value -eq 'spark') { 'Visible' } else { 'Collapsed' }
 foreach ($key in @('codex','spark')) {
  $button=if ($key -eq 'spark') { $ui.ModelSpark } else { $ui.ModelCodex }
  $button.Background=if ($key -eq $value) { '#39434F' } else { 'Transparent' }
  $button.Foreground=if ($key -eq $value) { if ($key -eq 'spark') { '#C6BFFF' } else { '#6DE0B9' } } else { '#AFBBC8' }
 }
 Resize-Widget
 if ($null -ne $script:lastEnvelope) { Show-Envelope $script:lastEnvelope }
 else { Show-State ([pscustomobject]@{ok=$false}) }
}
function Update-SourceChoices {
 $script:loadingSources=$true
 try {
  $ui.SourceChoice.Items.Clear()
  $options=@($script:sourceOptions)
  if ($options -notcontains $script:sourceSelection) { $options+= $script:sourceSelection }
  foreach ($option in $options) {
   $item=[Windows.Controls.ComboBoxItem]::new()
   $item.Tag=$option
   $item.Content=if ($option -eq 'auto') { T 'Automatique' } elseif ($option -eq 'windows') { 'Windows' } else { 'WSL / '+$option.Substring(4) }
   [void]$ui.SourceChoice.Items.Add($item)
   if ($option -eq $script:sourceSelection) { $ui.SourceChoice.SelectedItem=$item }
  }
  $ui.SourceLabel.Text=(T 'Source des quotas')
  $ui.SourceHint.Text=(T 'Choix enregistré automatiquement')
 } finally { $script:loadingSources=$false }
}
$ui.SourceChoice.Add_SelectionChanged({
 if ($script:loadingSources -or $null -eq $ui.SourceChoice.SelectedItem) { return }
 $value=[string]$ui.SourceChoice.SelectedItem.Tag
 if ($value -eq $script:sourceSelection) { return }
 $file=Join-Path $dataDir 'source.json'
 $tmp=$file+'.tmp'
 try {
  [IO.File]::WriteAllText($tmp,(@{source=$value}|ConvertTo-Json),[Text.UTF8Encoding]::new($false))
  if (Test-Path -LiteralPath $file) { [IO.File]::Replace($tmp,$file,$file+'.bak') } else { [IO.File]::Move($tmp,$file) }
  $script:sourceSelection=$value
  $script:lastEnvelope=$null
  $script:pendingDays=$null
  Show-State ([pscustomobject]@{ok=$false})
  $ui.Context.Text=(T 'Connexion à la source choisie…')
  [IO.File]::WriteAllText((Join-Path $dataDir 'refresh'),'')
 } catch { $ui.Context.Text=(T 'Enregistrement impossible · réessaie dans un instant.'); Update-SourceChoices }
})
function Show-Envelope($envelope) {
 if ($envelope.available_sources -and ($script:sourceOptions -join '|') -ne ($envelope.available_sources -join '|')) { $script:sourceOptions=@($envelope.available_sources); Update-SourceChoices }
 if ($envelope.requested_source -and $envelope.requested_source -ne $script:sourceSelection) { return }
 if (-not $envelope.requested_source -and $script:sourceSelection -ne 'auto' -and -not $Preview) { return }
 $script:lastEnvelope=$envelope
 if ($null -ne $envelope.models) { $entry=$envelope.models.($script:model) }
 elseif ($script:model -eq 'codex') { $entry=$envelope }
 else { $entry=[pscustomobject]@{ok=$false;error_code=$envelope.error_code;source=$envelope.source} }
 if ($null -eq $entry) { $entry=[pscustomobject]@{ok=$false;error_code=$envelope.error_code;source=$envelope.source} }
 if (-not $entry.ok -and $null -ne $script:pendingDays) { $script:pendingDays=$null }
 Show-State $entry
}
function Get-DiagnosticReport {
 $lines=[Collections.Generic.List[string]]::new()
 $lines.Add('Budget Codex 1.2.16')
 $lines.Add((T 'Source choisie')+': '+$script:sourceSelection)
 $lines.Add('Time zone: '+[TimeZoneInfo]::Local.Id)
 $lines.Add('')
 $events=@{connecting='Recherche de Codex';connected='Connexion établie';reading='Lecture des quotas';quotas_ok='Quotas reçus';snapshot_mode='Budget sans historique de compte';unavailable='Quota indisponible';error='Erreur'}
 try {
  $log=Get-Content -LiteralPath (Join-Path $dataDir 'diagnostics.json') -Raw -Encoding UTF8|ConvertFrom-Json
  if ($log.version) { $lines.Add('Monitor: '+$log.version) }
  foreach ($entry in @($log.entries)) {
   $stamp=[DateTimeOffset]::FromUnixTimeSeconds([long]$entry.at).ToLocalTime().ToString('HH:mm:ss')
   $label=if ($events.ContainsKey([string]$entry.event)) { T $events[[string]$entry.event] } else { T 'Erreur' }
   $line='['+$stamp+'] '+$label+' · '+$entry.source+' · '+$entry.stage
   if ($entry.code) { $line+=' · '+$entry.code }
   if ($null -ne $entry.rpc_code) { $line+=' · RPC '+$entry.rpc_code }
   if ($null -ne $entry.system_code) { $line+=' · OS '+$entry.system_code }
   if ($null -ne $entry.exit_code) { $line+=' · Exit '+$entry.exit_code }
   $lines.Add($line)
  }
  if (-not $log.entries) { $lines.Add((T 'En attente du premier diagnostic…')) }
 } catch { $lines.Add((T 'En attente du premier diagnostic…')) }
 return $lines -join [Environment]::NewLine
}
function Update-Diagnostic {
 $text=Get-DiagnosticReport
 if ($ui.DiagnosticConsole.Text -ne $text) { $ui.DiagnosticConsole.Text=$text; $ui.DiagnosticConsole.ScrollToEnd() }
}
$ui.CopyDiagnostic.Add_Click({
 try { [Windows.Clipboard]::SetText((Get-DiagnosticReport)); $ui.CopyDiagnostic.Content=(T 'Copié !') }
 catch { $ui.CopyDiagnostic.Content=(T 'Copie impossible') }
})
function Update-Widget {
 Update-Diagnostic
 $file=Join-Path $dataDir 'status.json'
 if (Test-Path -LiteralPath $file) { try { $s=Get-Content -LiteralPath $file -Raw -Encoding UTF8|ConvertFrom-Json } catch { return }; Show-Envelope $s }
}
$ui.ModelCodex.Add_Click({ Set-Model 'codex' -Persist })
$ui.ModelSpark.Add_Click({ Set-Model 'spark' -Persist })
$ui.LangFR.Add_Click({ Set-Language 'fr' -Persist })
$ui.LangEN.Add_Click({ Set-Language 'en' -Persist })
$timer=[Windows.Threading.DispatcherTimer]::new(); $timer.Interval=[TimeSpan]::FromSeconds(2); $timer.Add_Tick({ Update-Widget })
if (-not $Preview) {
 $exe=Join-Path $PSScriptRoot 'bin\BudgetMonitor.exe'
 if (-not (Test-Path -LiteralPath $exe)) { throw (T (T "BudgetMonitor.exe absent.")) }
 Start-Process -FilePath $exe -ArgumentList @('--data',('"'+$dataDir+'"'),'--parent',$PID) -WindowStyle Hidden | Out-Null
}
$window.Add_Closed({ $timer.Stop(); if (-not $Preview) { @{left=$window.Left;top=$window.Top;pin=$window.Topmost}|ConvertTo-Json|Set-Content -LiteralPath $settings -Encoding UTF8 } })
try {
 Set-Language $script:language
 Set-Model $script:model
 Update-Widget
 if ($Preview) {
  if ($PreviewState -ne 'live') {
   $demo=[pscustomobject]@{ok=$true;updated=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds();reset=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()+518400;standard_cap=(100.0/7);cap=(100.0/7);day='10/09';remaining=77;used=23;today_low=5;uncertain=$false;opening_bonus_low=2;opening_bonus_high=2;bonus_low=2;bonus_high=2;available=(100.0/7+2-5);working_today=$true;reset_label='16/09 à 08:36';workdays=@(0,1,2,3,4,5,6)}
   if ($PreviewState -eq 'bonus') { $demo.today_low=(100.0/7+1); $demo.used=39; $demo.remaining=61; $demo.bonus_low=1; $demo.bonus_high=1; $demo.available=1 }
   if ($PreviewState -eq 'partial') { $demo.uncertain=$true; $demo.today_low=1; $demo.opening_bonus_high=15; $demo.bonus_high=15 }
   if ($PreviewState -eq 'offline') { $demo.ok=$false }
   # Preview controls and figures share the same synthetic schedule, never personal settings.
   foreach ($box in $dayBoxes) { $box.IsChecked=$demo.workdays -contains [int]$box.Tag }
   $script:pendingDays=$null
   $sparkDemo=$demo.PSObject.Copy()
   $sparkDemo | Add-Member -NotePropertyName short -NotePropertyValue ([pscustomobject]@{ok=$true;remaining=68;used=32;updated=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds();reset=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()+7200})
   Show-Envelope ([pscustomobject]@{models=[pscustomobject]@{codex=$demo;spark=$sparkDemo}})
   if ($PreviewState -eq 'settings') { $ui.SettingsPanel.Visibility='Visible'; Resize-Widget }
  }
  $window.Show(); $window.UpdateLayout()
  $bitmap=[Windows.Media.Imaging.RenderTargetBitmap]::new([int]$window.ActualWidth,[int]$window.ActualHeight,96,96,[Windows.Media.PixelFormats]::Pbgra32); $bitmap.Render($window)
  $encoder=[Windows.Media.Imaging.PngBitmapEncoder]::new(); $encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
  $stream=[IO.File]::Create((Join-Path $PSScriptRoot ("preview-$PreviewState-$script:language-$script:model.png"))); $encoder.Save($stream); $stream.Dispose(); $window.Close()
 } else { $timer.Start(); $window.ShowDialog()|Out-Null }
} finally { $timer.Stop(); if ($ownsMutex) { $mutex.ReleaseMutex() }; $mutex.Dispose() }
