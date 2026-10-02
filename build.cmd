@echo off
set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
if not exist "%VSWHERE%" (
    echo Visual Studio Installer's vswhere.exe was not found.
    exit /b 1
)
for /f "usebackq delims=" %%I in (`"%VSWHERE%" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -find VC\Auxiliary\Build\vcvars32.bat`) do set "VCVARS=%%I"
if not defined VCVARS (
    echo Visual C++ x86 build tools were not found.
    exit /b 1
)
call "%VCVARS%" >nul
if errorlevel 1 exit /b %errorlevel%
cl.exe /nologo /LD /O2 /W4 /MT poc.c advapi32.lib /link /DEF:poc.def /OUT:IPHLPAPI.DLL
