; 1o1-ai Windows Installer Script
; Built for ManjuLAB / whizyoga-ai
; Connects local backend to yogabrata.com frontend

!define APP_NAME "1o1 AI"
!define APP_VERSION "1.0.0"
!define APP_PUBLISHER "ManjuLAB"
!define APP_URL "https://yogabrata.com"
!define INSTALL_DIR "$PROGRAMFILES64\1o1-ai"
!define OUTPUT_FILE "1o1-ai-setup.exe"

Name "${APP_NAME} ${APP_VERSION}"
OutFile "${OUTPUT_FILE}"
InstallDir "${INSTALL_DIR}"
InstallDirRegKey HKLM "Software\ManjuLAB\1o1-ai" "Install_Dir"
RequestExecutionLevel admin
SetCompressor /SOLID lzma

!include "MUI2.nsh"
!include "LogicLib.nsh"

!define MUI_ABORTWARNING
!define MUI_ICON "assets\icon.ico"
!define MUI_UNICON "assets\icon.ico"
!define MUI_WELCOMEPAGE_TITLE "Welcome to 1o1 AI by ManjuLAB"
!define MUI_WELCOMEPAGE_TEXT "This installer will set up the 1o1 AI conversational backend on your machine.$\r$\n$\r$\nThe local server runs at wss://localhost:8998 and connects seamlessly to the live demo at yogabrata.com.$\r$\n$\r$\nClick Next to continue."
!define MUI_FINISHPAGE_RUN "$INSTDIR\start-1o1.bat"
!define MUI_FINISHPAGE_RUN_TEXT "Launch 1o1 AI server now"
!define MUI_FINISHPAGE_LINK "Open yogabrata.com demo"
!define MUI_FINISHPAGE_LINK_LOCATION "https://yogabrata.com/demo.html"

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE "LICENSE-MIT"
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "English"

Section "1o1 AI Backend" SecMain
  SectionIn RO
  SetOutPath "$INSTDIR"

  ; Copy all backend files
  File /r "*.*"

  ; Write registry keys
  WriteRegStr HKLM "Software\ManjuLAB\1o1-ai" "Install_Dir" "$INSTDIR"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\1o1-ai" "DisplayName" "1o1 AI by ManjuLAB"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\1o1-ai" "UninstallString" "$INSTDIR\uninstall.exe"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\1o1-ai" "DisplayVersion" "${APP_VERSION}"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\1o1-ai" "Publisher" "${APP_PUBLISHER}"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\1o1-ai" "URLInfoAbout" "${APP_URL}"

  ; Create Start Menu shortcut
  CreateDirectory "$SMPROGRAMS\1o1 AI"
  CreateShortCut "$SMPROGRAMS\1o1 AI\1o1 AI Server.lnk" "$INSTDIR\start-1o1.bat"
  CreateShortCut "$SMPROGRAMS\1o1 AI\1o1 AI Demo (yogabrata.com).lnk" "https://yogabrata.com/demo.html"
  CreateShortCut "$SMPROGRAMS\1o1 AI\Uninstall 1o1 AI.lnk" "$INSTDIR\uninstall.exe"

  ; Desktop shortcut
  CreateShortCut "$DESKTOP\1o1 AI Server.lnk" "$INSTDIR\start-1o1.bat"

  ; Run PowerShell setup (Python, venv, model weights, SSL cert)
  ExecWait 'powershell.exe -ExecutionPolicy Bypass -File "$INSTDIR\installer\setup.ps1"' $0
  ${If} $0 != 0
    MessageBox MB_ICONEXCLAMATION "Setup script encountered an error (code $0). Check logs at $INSTDIR\setup.log"
  ${EndIf}

  WriteUninstaller "$INSTDIR\uninstall.exe"
SectionEnd

Section "Uninstall"
  Delete "$INSTDIR\uninstall.exe"
  RMDir /r "$INSTDIR"
  Delete "$SMPROGRAMS\1o1 AI\*.*"
  RMDir "$SMPROGRAMS\1o1 AI"
  Delete "$DESKTOP\1o1 AI Server.lnk"
  DeleteRegKey HKLM "Software\ManjuLAB\1o1-ai"
  DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\1o1-ai"
    SectionEnd
