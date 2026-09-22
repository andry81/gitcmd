@echo off & goto DOC_END

rem USAGE:
rem   git_cd.sh [<path>]

rem Description:
rem   Script changes current directory to the root of a working copy beginning
rem   the <path>.

rem <path>
rem   A path in a working copies tree.
rem   Has no effect if is not in a working copy.
rem
rem   Builtin paths:
rem     // - top level working copy root.
rem     /  - current working copy root.
rem
rem   If <path> is empty, then `/` is used instead.

rem CAUTION:
rem   The delayed expansion feature must be disabled before this script call:
rem   `setlocal DISABLEDELAYEDEXPANSION`, otherwise the `!` character will be
rem   expanded.
:DOC_END

setlocal DISABLEDELAYEDEXPANSION

set "CWD=%~1"

if not defined CWD set "CWD=/"

if "%CWD%" == "/" (
  set "WCROOT="
  for /F "usebackq tokens=* delims="eol^= %%i in (`git rev-parse --show-toplevel 2^>nul`) do set "WCROOT=%%i"
  if defined WCROOT setlocal ENABLEDELAYEDEXPANSION & for /F "tokens=* delims="eol^= %%i in ("!WCROOT!") do endlocal & endlocal & cd "%%i"
) else if "%CWD%" == "//" (
  set "WCROOT="
  for /F "usebackq tokens=* delims="eol^= %%i in (`git rev-parse --show-toplevel 2^>nul`) do set "WCROOT=%%i"
  if defined WCROOT goto CDTOPROOT
) else setlocal ENABLEDELAYEDEXPANSION & for /F "tokens=* delims="eol^= %%i in ("!CWD!") do endlocal & cd "%%i" && (
  set "WCROOT="
  for /F "usebackq tokens=* delims="eol^= %%i in (`git rev-parse --show-toplevel 2^>nul`) do set "WCROOT=%%i"
  if defined WCROOT setlocal ENABLEDELAYEDEXPANSION & for /F "tokens=* delims="eol^= %%i in ("!WCROOT!") do endlocal & endlocal & cd "%%i"
)

exit /b

:CDTOPROOT
set "WCTOPROOT=%WCROOT%"
cd "%WCROOT%/.." 2>nul && (
  set "WCROOT="
  for /F "usebackq tokens=* delims="eol^= %%i in (`git rev-parse --show-toplevel 2^>nul`) do set "WCROOT=%%i"
  if defined WCROOT goto CDTOPROOT
)
setlocal ENABLEDELAYEDEXPANSION & for /F "tokens=* delims="eol^= %%i in ("!WCTOPROOT!") do endlocal & endlocal & cd "%%i"
