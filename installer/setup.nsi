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
!define MUI_WELCOMEPAGE_TITLE "Welcome to 1o1 AI by ManjuLAB"
!define MUI_WELCOMEPAGE_TEXT "This installer sets up 1o1 AI on your computer.$\r$\n$\r$\nSteps:$\r$\n- Install Python 3.11 if needed$\r$\n- Download Moshi voice model$\r$\n- Configure local WebSocket server$\r$\n$\r$\nClick Next to continue."

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "English"

Section "Install" SecInstall
    SetOutPath "${INSTALL_DIR}"
    File "setup.ps1"
    File "start-1o1.bat"

    CreateDirectory "$SMPROGRAMS\1o1 AI"
    CreateShortcut "$SMPROGRAMS\1o1 AI\1o1 AI.lnk" "${INSTALL_DIR}\start-1o1.bat"
    CreateShortcut "$DESKTOP\1o1 AI.lnk" "${INSTALL_DIR}\start-1o1.bat"

    nsExec::ExecToLog 'powershell.exe -ExecutionPolicy Bypass -File "${INSTALL_DIR}\setup.ps1"'

    WriteRegStr HKLM "Software\ManjuLAB\1o1-ai" "Install_Dir" "${INSTALL_DIR}"
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\1o1-ai" "DisplayName" "${APP_NAME}"
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\1o1-ai" "UninstallString" "${INSTALL_DIR}\uninstall.exe"
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\1o1-ai" "Publisher" "${APP_PUBLISHER}"
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\1o1-ai" "URLInfoAbout" "${APP_URL}"
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\1o1-ai" "DisplayVersion" "${APP_VERSION}"

    WriteUninstaller "${INSTALL_DIR}\uninstall.exe"
SectionEnd

Section "Uninstall"
    Delete "${INSTALL_DIR}\setup.ps1"
    Delete "${INSTALL_DIR}\start-1o1.bat"
    Delete "${INSTALL_DIR}\config.json"
    Delete "${INSTALL_DIR}\uninstall.exe"
    RMDir /r "${INSTALL_DIR}\venv"
    RMDir "${INSTALL_DIR}"
    Delete "$DESKTOP\1o1 AI.lnk"
    Delete "$SMPROGRAMS\1o1 AI\1o1 AI.lnk"
    RMDir "$SMPROGRAMS\1o1 AI"
    DeleteRegKey HKLM "Software\ManjuLAB\1o1-ai"
    DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\1o1-ai"
SectionEnd
