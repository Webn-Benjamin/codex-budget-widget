#define Version "1.2.12"
#ifdef TestBuild
 #define ProductName "Budget Codex Installer Test"
 #define ProductId "BudgetCodexInstallerTest"
 #define OutputName "Budget-Codex-Test-Setup"
#else
 #define ProductName "Budget Codex"
 #define ProductId "BudgetCodexWidget"
 #define OutputName "Budget-Codex-Setup"
#endif

[Setup]
AppId={#ProductId}
AppName={#ProductName}
AppVersion={#Version}
AppPublisher=Budget Codex
DefaultDirName={localappdata}\Programs\{#ProductId}
DefaultGroupName={#ProductName}
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
DisableWelcomePage=yes
DisableDirPage=yes
DisableProgramGroupPage=yes
DisableFinishedPage=yes
ShowLanguageDialog=no
LanguageDetectionMethod=uilanguage
WizardStyle=modern
OutputDir=..\dist
OutputBaseFilename={#OutputName}
Compression=lzma2
SolidCompression=yes
UninstallDisplayIcon={app}\BudgetCodex.ico
SetupIconFile=BudgetCodex.ico
#ifndef TestBuild
AppMutex=Local\CodexBudgetWidget_v1
#endif
CloseApplications=yes
RestartApplications=no
Uninstallable=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "french"; MessagesFile: "compiler:Languages\French.isl"

[CustomMessages]
english.Intro=Your daily Codex budget, always in view.
english.Details=This will install Budget Codex, create desktop and Start menu shortcuts, and open the widget.%n%nYou need Codex installed and signed in. No Python or administrator access is required.%n%nUpdates preserve your history. Choose French or English using FR / EN in the widget header.
french.Intro=Votre budget Codex quotidien, toujours sous les yeux.
french.Details=Budget Codex sera installé, un raccourci sera créé sur le bureau et dans le menu Démarrer, puis le widget sera ouvert.%n%nCodex doit être installé avec votre compte connecté. Aucun besoin de Python ni de droits administrateur.%n%nLes mises à jour conservent votre historique.

[Files]
Source: "..\i18n.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\widget.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\bin\BudgetMonitor.exe"; DestDir: "{app}\bin"; Flags: ignoreversion
Source: "..\README.md"; DestDir: "{app}"; Flags: ignoreversion
Source: "launch.vbs"; DestDir: "{app}"; Flags: ignoreversion
Source: "launch.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "BudgetCodex.ico"; DestDir: "{app}"; Flags: ignoreversion

#ifndef TestBuild
[Icons]
Name: "{userdesktop}\Budget Codex"; Filename: "{sys}\wscript.exe"; Parameters: """{app}\launch.vbs"""; WorkingDir: "{app}"; IconFilename: "{app}\BudgetCodex.ico"
Name: "{userprograms}\Budget Codex"; Filename: "{sys}\wscript.exe"; Parameters: """{app}\launch.vbs"""; WorkingDir: "{app}"; IconFilename: "{app}\BudgetCodex.ico"

[Run]
Filename: "{sys}\wscript.exe"; Parameters: """{app}\launch.vbs"""; Flags: nowait skipifsilent
#endif

[Code]
procedure InitializeWizard;
begin
  WizardForm.ReadyLabel.Caption := ExpandConstant('{cm:Intro}');
  WizardForm.ReadyMemo.Text := ExpandConstant('{cm:Details}');
end;

procedure CurPageChanged(CurPageID: Integer);
begin
  if CurPageID = wpReady then
    WizardForm.ReadyMemo.Text := ExpandConstant('{cm:Details}');
end;

#ifndef TestBuild
function InitializeUninstall: Boolean;
begin
  Result := not CheckForMutexes('Local\CodexBudgetWidget_v1');
  if not Result then
    SuppressibleMsgBox('Close Budget Codex before uninstalling. / Fermez Budget Codex avant de le désinstaller.', mbInformation, MB_OK, IDOK);
end;
#endif
