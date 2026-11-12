!ifndef OUTFILE
  !define OUTFILE "synce-windows-setup.exe"
!endif

!ifndef BINDIR
  !define BINDIR "client\build\windows\x64\runner\Release"
!endif

!ifndef VERSION
  !define VERSION "1.0.0"
!endif

!define APPNAME "Synce"
!define APPEXE "synce.exe"

Name "${APPNAME}"
OutFile "${OUTFILE}"
InstallDir "$LOCALAPPDATA\Programs\Synce"
InstallDirRegKey HKCU "Software\Synce" "InstallDir"
RequestExecutionLevel user
SetCompressor /SOLID lzma
VIProductVersion "${VERSION}.0"

!include "MUI2.nsh"
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_LANGUAGE "English"

Section "Install"
  SetOutPath "$INSTDIR"
  File /r "${BINDIR}\*"
  WriteUninstaller "$INSTDIR\Uninstall.exe"
  WriteRegStr HKCU "Software\Synce" "InstallDir" "$INSTDIR"

  CreateDirectory "$SMPROGRAMS\Synce"
  CreateShortcut "$SMPROGRAMS\Synce\Synce.lnk" "$INSTDIR\${APPEXE}"
  CreateShortcut "$SMPROGRAMS\Synce\Uninstall Synce.lnk" "$INSTDIR\Uninstall.exe"
  CreateShortcut "$DESKTOP\Synce.lnk" "$INSTDIR\${APPEXE}"

  ExecShell "" "$INSTDIR\${APPEXE}"
SectionEnd

Section "Uninstall"
  Delete "$INSTDIR\Uninstall.exe"
  RMDir /r "$INSTDIR"
  Delete "$SMPROGRAMS\Synce\Synce.lnk"
  Delete "$SMPROGRAMS\Synce\Uninstall Synce.lnk"
  RMDir "$SMPROGRAMS\Synce"
  Delete "$DESKTOP\Synce.lnk"
  DeleteRegKey HKCU "Software\Synce"
SectionEnd
