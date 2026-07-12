; ============================================================================
;  FastFlow VPN — Windows installer (Inno Setup 6)
;
;  Bundles the Flutter desktop app + native vpn_engine.dll + the elevated
;  helper daemon, registers/starts the daemon as a Windows service, and writes
;  the daemon's client allowlist to the exact installed app path so the daemon's
;  PID/path verification passes without any manual step.
;
;  Build order (see the checklist at the end of this file):
;    1) make engine-windows        -> windows\vpn_engine.dll
;    2) flutter build windows -t main.dart --release
;                                   -> build\windows\x64\runner\Release\  (incl. vpn_engine.dll)
;    3) build the daemon           -> windows_daemon\fastflow-daemon.exe
;    4) ISCC installer\inno_setup.iss
;
;  Compile from the repo root:  iscc installer\inno_setup.iss
;  (Relative Source paths below are resolved against this .iss file's folder.)
; ============================================================================

#define MyAppName        "FastFlow VPN"
#define MyAppVersion     "1.0.4"
#define MyAppPublisher   "FastFlow"
#define MyAppExeName     "fastflow_vpn.exe"
#define DaemonExeName    "fastflow-daemon.exe"
#define ServiceName      "FastFlowHelper"

; Build outputs, relative to this script (installer/ is one level under the repo root).
#define BuildDir   "..\build\windows\x64\runner\Release"
#define DaemonDir  "..\windows_daemon"
#define EngineDll  "..\windows\vpn_engine.dll"

[Setup]
; A stable AppId keeps upgrades/uninstall tied to the same product. Keep constant.
AppId={{7B2E4C9A-1F3D-4A56-9E8B-2C4D6F8A0B13}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\FastFlow
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
UninstallDisplayIcon={app}\{#MyAppExeName}
OutputBaseFilename=FastFlowVPN-Setup-{#MyAppVersion}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
MinVersion=10.0
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
; Setup must run elevated: it installs a Windows service and writes to Program Files.
PrivilegesRequired=admin

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; The entire Flutter release folder: fastflow_vpn.exe, flutter_windows.dll,
; the data\ folder (flutter_assets, icudtl.dat, ...) and vpn_engine.dll (the
; CMake POST_BUILD step already copied it here).
Source: "{#BuildDir}\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion

; Fallback: if vpn_engine.dll wasn't bundled into the release folder (engine
; built after `flutter build`), copy it directly. Harmless if already present.
Source: "{#EngineDll}"; DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist

; The elevated helper service binary.
Source: "{#DaemonDir}\{#DaemonExeName}"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\Uninstall {#MyAppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
; Register the helper as an auto-start Windows service (the exe records its own
; installed path as the service binary). Any stale service was removed in
; CurStepChanged(ssInstall) below, so this is always a clean registration.
Filename: "{app}\{#DaemonExeName}"; Parameters: "install"; StatusMsg: "Installing FastFlow helper service..."; Flags: runhidden waituntilterminated

; Start it now (StartType is Automatic, so it also comes up on reboot). The
; service generates its shared-secret token on first run.
Filename: "{sys}\sc.exe"; Parameters: "start {#ServiceName}"; StatusMsg: "Starting FastFlow helper service..."; Flags: runhidden waituntilterminated

; Optional launch on finish.
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#MyAppName}}"; Flags: nowait postinstall skipifsilent

[UninstallRun]
; Stop + remove the service BEFORE files are deleted (the exe must still exist).
Filename: "{sys}\sc.exe"; Parameters: "stop {#ServiceName}"; Flags: runhidden waituntilterminated; RunOnceId: "StopFastFlowSvc"
Filename: "{app}\{#DaemonExeName}"; Parameters: "uninstall"; Flags: runhidden waituntilterminated; RunOnceId: "RemoveFastFlowSvc"

[UninstallDelete]
; Remove the daemon's runtime state (token, allowlist, log).
Type: filesandordirs; Name: "{commonappdata}\FastFlow"

[Code]
{ Stop and delete any previously-installed service before copying files, so the
  helper exe isn't locked during an upgrade and re-registration is clean. }
procedure StopExistingService;
var
  ResultCode: Integer;
begin
  Exec(ExpandConstant('{sys}\sc.exe'), 'stop {#ServiceName}', '',
       SW_HIDE, ewWaitUntilTerminated, ResultCode);
  Exec(ExpandConstant('{sys}\sc.exe'), 'delete {#ServiceName}', '',
       SW_HIDE, ewWaitUntilTerminated, ResultCode);
  { Give the SCM a moment to release the executable handle. }
  Sleep(1500);
end;

{ Point the daemon's allowlist at the exact installed client path, so its
  loopback-port -> PID -> image-path check accepts our GUI automatically. }
procedure WriteClientAllowlist;
var
  Dir, AllowlistPath, ClientPath: string;
begin
  Dir := ExpandConstant('{commonappdata}\FastFlow');
  ForceDirectories(Dir);
  AllowlistPath := Dir + '\client_allowlist.txt';
  ClientPath := ExpandConstant('{app}\{#MyAppExeName}');
  SaveStringToFile(AllowlistPath, ClientPath + #13#10, False);
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssInstall then
    StopExistingService
  else if CurStep = ssPostInstall then
    WriteClientAllowlist;
end;
