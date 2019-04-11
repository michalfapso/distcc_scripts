@echo off

if not defined MSYS2_DIR (
	echo Please, define MSYS2_DIR environment variable, e.g. MSYS2_DIR=C:\msys2
	rem exit /B switch: to exit the current batch script context, and not the command prompt process
	exit /B 1
)

set "PWD=%cd:\=/%"
rem echo "PWD: %PWD%"

set "MSYS2_DIR_FWD=%MSYS2_DIR:\=/%"
rem echo MSYS2_DIR_FWD: %MSYS2_DIR_FWD%

"%MSYS2_DIR%"\usr\bin\env MSYSTEM=MINGW64 "%MSYS2_DIR%"\usr\bin\bash -l -c "cd %PWD%; %MSYS2_DIR_FWD%/usr/bin/distcc_make.sh %*"

