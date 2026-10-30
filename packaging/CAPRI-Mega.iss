#define MyAppName "CAPRI Mega"
#define MyAppVersion "1.0.0"
[Setup]
AppId={{A9D1D20C-29F0-4C14-90C6-1D98C8E9B9F2}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
DefaultDirName={localappdata}\Programs\CAPRI Mega
DefaultGroupName=CAPRI Mega
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
OutputDir=..\out\installer
OutputBaseFilename=CAPRI-Mega-Setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesInstallIn64BitMode=x64
UninstallDisplayIcon={app}\companion\Capri.exe
[Files]
Source: "..\out\standalone\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
[Icons]
Name: "{autoprograms}\CAPRI Mega"; Filename: "powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\Launch-CAPRI.ps1"""
Name: "{autodesktop}\CAPRI Mega"; Filename: "powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\Launch-CAPRI.ps1"""; Tasks: desktopicon
[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional shortcuts:"
[Run]
Filename: "powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\Launch-CAPRI.ps1"""; Description: "Launch CAPRI Mega"; Flags: postinstall nowait skipifsilent
