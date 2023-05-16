@echo off

setlocal EnableDelayedExpansion

@rem ***************************************************************************
@rem The entry point
@rem ***************************************************************************

set PRJ=chest
set VER=0.1.0

@rem ***************************************************************************
@rem Initialising directory paths
@rem ***************************************************************************

set APP=app\Windows
set BIN=bin\Windows
set OUP=out\Windows
set OUT=%OUP%\%PRJ%\%VER%

@rem ***************************************************************************
@rem Initialising file paths
@rem ***************************************************************************

set EXE=%BIN%\%PRJ%.exe
set PKG=%APP%\%PRJ%-%VER%-windows-x86_64
set XNX=%BIN%\xnx.exe

@rem ***************************************************************************
@rem Switching to the project's top directory
@rem ***************************************************************************

%~d0
if errorlevel 1 exit /B 1

cd "%~dp0.."
if errorlevel 1 exit /B 1

@echo Switched to the project's top directory "%CD%"
@echo Parsing the script's command-line arguments and grabbing the extra ones

if not "%~1" == "" shift
set ARGS=%*

@rem ***************************************************************************

echo Running the build for Windows

if not exist "%APP%" (
  echo Creating the application directory "%APP%"
  mkdir "%APP%"
  if errorlevel 1 exit /B 1
)

if not exist "%BIN%" (
  echo Creating the bin directory "%BIN%"
  mkdir "%BIN%"
  if errorlevel 1 exit /B 1
)

if exist "%OUP%" (
  echo Discarding the output parent directory "%OUP%"
  rmdir /Q /S "%OUP%"
)

echo Creating the output directory "%OUT%"
mkdir "%OUT%"
if errorlevel 1 exit /B 1

@rem ***************************************************************************

echo Getting the latest version of the packages
call dart pub get
if errorlevel 1 exit /B 1

echo Compiling "%EXE%"
dart compile exe bin\main.dart -o "%EXE%"
if errorlevel 1 exit /B 1

echo Copying the executable file to the output directory
copy /Y "%EXE%" "%OUT%"
if errorlevel 1 exit /B 1

echo Copying the version switcher to the output directory
copy /Y scripts\set-as-current.bat "%OUT%"
if errorlevel 1 exit /B 1

echo Copying the change log, installation guide and license to the output directory
copy /Y *.md "%OUT%"
if errorlevel 1 exit /B 1

echo Creating the icons in the output directory
"%XNX%" -d scripts\mkicons "%PRJ%" "..\..\%OUT%" %ARGS%
if errorlevel 1 exit /B 1

echo Creating and compressing the application package
"%XNX%" --move --pack "%OUP%\%PRJ%" "%PKG%.zip"

@rem ***************************************************************************

echo Removing the output parent directory "%OUP%"
rmdir /Q /S "%OUP%"

@rem ***************************************************************************

echo The build successfully completed
exit /B 0

@rem ***************************************************************************
