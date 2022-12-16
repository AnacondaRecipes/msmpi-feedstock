if "%ARCH%"=="32" (
    set PLATFORM=Win32
) else (
    set PLATFORM=x64
)

@REM Install Microsoft.VisualStudio.Component.VC.Runtimes.x86.x64.Spectre
START /WAIT "" "C:\Program Files (x86)\Microsoft Visual Studio\Installer\vs_installer.exe" modify --installPath "C:\Program Files (x86)\Microsoft Visual Studio\2017\BuildTools" --passive --add Microsoft.VisualStudio.Component.VC.Runtimes.x86.x64.Spectre

@REM Install dot NET core 2.1.818 using dotnet-install scripts
curl -L -o %BUILD_PREFIX%/dotnet-install.ps1 https://dot.net/v1/dotnet-install.ps1
powershell %BUILD_PREFIX%/dotnet-install.ps1 -InstallDir %BUILD_PREFIX%/dotnet -Version 2.1.818
set PATH=%BUILD_PREFIX%/dotnet;%BUILD_PREFIX%\dotnet\sdk\2.1.818;%PATH%
set MSBuildSDKsPath=%BUILD_PREFIX%\dotnet\sdk\2.1.818\Sdks

@REM Install WDK: Requires Admin rights
@REM Find WDK URL for this version of Windows. In this case, 1809:
@REM https://learn.microsoft.com/en-us/windows-hardware/drivers/other-wdk-downloads
curl -L -o wdksetup.exe https://download.microsoft.com/download/1/4/0/140EBDB7-F631-4191-9DC0-31C8ECB8A11F/wdk/wdksetup.exe
START /WAIT wdksetup.exe /features + /q

@REM Hack to make WDK compatible with Visual Studio Build Tools
@REM See: https://social.msdn.microsoft.com/Forums/en-US/efe5f9f8-c32d-4a25-87e2-abbe711dadbb/no-wdk-support-for-visual-studio-2017-build-tools?forum=wdk
7z x "C:\Program Files (x86)\Windows Kits\10\Vsix\WDK.vsix" -o%BUILD_PREFIX%\WDK
robocopy "%BUILD_PREFIX%\WDK\$VCTargets" "C:\Program Files (x86)\Microsoft Visual Studio\2017\BuildTools\Common7\IDE\VC\VCTargets" /s /e *.*

msbuild.exe /p:Platform=%PLATFORM% /p:Configuration=Release

for /r %SRC_DIR%\out\Release-%PLATFORM% %%f in (*.exe) do @copy "%%f" %LIBRARY_BIN%
for /r %SRC_DIR%\out\Release-%PLATFORM% %%f in (*.dll) do @copy "%%f" %LIBRARY_BIN%
for /r %SRC_DIR%\out\Release-%PLATFORM% %%f in (*.lib) do @copy "%%f" %LIBRARY_LIB%
for /r %SRC_DIR%\out\Release-%PLATFORM% %%f in (*.f90) do @copy "%%f" %LIBRARY_INC%
for /r %SRC_DIR%\out\Release-%PLATFORM% %%f in (*.h) do @copy "%%f" %LIBRARY_INC%

rem ensure the correct header for the platform is added 
if "%ARCH%"=="32" (
    copy %SRC_DIR%\out\Release-x64\bin\sdk\inc\x86\mpifptr.h %LIBRARY_INC%\mpifptr.h
) else (
    copy %SRC_DIR%\out\Release-x64\bin\sdk\inc\x64\mpifptr.h %LIBRARY_INC%\mpifptr.h
)

setlocal EnableDelayedExpansion

:: Copy the [de]activate scripts to %PREFIX%\etc\conda\[de]activate.d.
:: This will allow them to be run on environment activation.
for %%F in (activate deactivate) DO (
    if not exist %PREFIX%\etc\conda\%%F.d mkdir %PREFIX%\etc\conda\%%F.d
    copy %RECIPE_DIR%\%%F.bat %PREFIX%\etc\conda\%%F.d\%PKG_NAME%_%%F.bat || exit 1
)

echo "patching mpi.h..."
:: add --binary to handle the CRLF line ending
patch --binary "%LIBRARY_INC%\mpi.h" "%RECIPE_DIR%\MSMPI_VER.diff" || exit 1

dir /s /b
