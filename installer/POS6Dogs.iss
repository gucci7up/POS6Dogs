#define AppName      "MBSport Racing Dogs"
#define AppVersion   "1.0.0"
#define AppPublisher "MBSport"
#define AppExeName   "pos.exe"
#define ReleaseDir   "..\build\windows\x64\runner\Release"
#define IconFile     "..\windows\runner\resources\app_icon.ico"

[Setup]
AppId={{A3B2C1D0-BEEF-4321-ABCD-POS6DOGS2026}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
DefaultDirName={sd}\POS6Dogs
DefaultGroupName={#AppName}
AllowNoIcons=no
OutputDir=.
OutputBaseFilename=MBSport_Racing_Dogs_Setup
SetupIconFile={#IconFile}
UninstallDisplayIcon={app}\{#AppExeName}
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin
ArchitecturesInstallIn64BitMode=x64compatible

[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"

[Tasks]
Name: "desktopicon"; Description: "Crear icono en el escritorio"; GroupDescription: "Iconos adicionales:"; Flags: checkedonce

[Files]
; Ejecutable principal
Source: "{#ReleaseDir}\{#AppExeName}";   DestDir: "{app}"; Flags: ignoreversion

; DLLs de Flutter
Source: "{#ReleaseDir}\flutter_windows.dll";          DestDir: "{app}"; Flags: ignoreversion
Source: "{#ReleaseDir}\screen_retriever_plugin.dll";  DestDir: "{app}"; Flags: ignoreversion
Source: "{#ReleaseDir}\window_manager_plugin.dll";    DestDir: "{app}"; Flags: ignoreversion
Source: "{#ReleaseDir}\printing_plugin.dll";          DestDir: "{app}"; Flags: ignoreversion
Source: "{#ReleaseDir}\pdfium.dll";                   DestDir: "{app}"; Flags: ignoreversion

; Carpeta data completa (assets, fuentes, shaders, etc.)
Source: "{#ReleaseDir}\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
; Acceso directo en el menú inicio
Name: "{group}\{#AppName}";          Filename: "{app}\{#AppExeName}"; IconFilename: "{app}\{#AppExeName}"
Name: "{group}\Desinstalar {#AppName}"; Filename: "{uninstallexe}"

; Acceso directo en el escritorio (solo si la tarea "desktopicon" fue seleccionada)
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; IconFilename: "{app}\{#AppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExeName}"; Description: "Iniciar {#AppName}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
Type: filesandordirs; Name: "{app}"
