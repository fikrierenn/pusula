@echo off
REM BKM Kitap - Tahmin motoru tetikleyicisi (plan-15 Faz 1).
REM scripts/forecast/run.py -> dashboard/data/forecast/*.json (dashboard /tahmin okur).
REM Zamanlanmis gorev (Gorev Zamanlayici) ile gunluk/haftalik calistirilir.
REM send_brief.bat'taki kanitlanmis Python-bulma mantigi yeniden kullanilir.

setlocal enabledelayedexpansion
cd /d "%~dp0"

set LOGFILE=%~dp0run_forecast.log
echo [%date% %time%] Basladi > "%LOGFILE%"
echo [%date% %time%] CWD: %CD% >> "%LOGFILE%"

REM ===========================================================
REM Python bul (send_brief.bat ile ayni mantik)
REM ===========================================================
set "PYCMD="

for /f "delims=" %%P in ('where python 2^>nul') do (
    if not defined PYCMD (
        if exist "%%P" set "PYCMD=%%P"
    )
)
if not defined PYCMD (
    for %%V in (3.13 3.12 3.11 3.10 3) do (
        if not defined PYCMD (
            for /f "delims=" %%P in ('py -%%V -c "import sys; print(sys.executable)" 2^>nul') do (
                if exist "%%P" set "PYCMD=%%P"
            )
        )
    )
)
if not defined PYCMD (
    for %%P in (
        "%ProgramFiles%\Python312\python.exe"
        "%ProgramFiles%\Python313\python.exe"
        "C:\Python312\python.exe"
        "C:\Python313\python.exe"
        "%LOCALAPPDATA%\Programs\Python\Python312\python.exe"
        "%LOCALAPPDATA%\Programs\Python\Python313\python.exe"
    ) do (
        if not defined PYCMD (
            if exist %%P set "PYCMD=%%~P"
        )
    )
)

if not defined PYCMD (
    echo [HATA] Calisabilir Python bulunamadi >> "%LOGFILE%"
    exit /b 2
)

echo [%date% %time%] Python: "%PYCMD%" >> "%LOGFILE%"
"%PYCMD%" --version >> "%LOGFILE%" 2>&1

REM ===========================================================
REM Tahmin motoru calistir
REM ===========================================================
echo [%date% %time%] run.py basliyor >> "%LOGFILE%"
"%PYCMD%" scripts\forecast\run.py >> "%LOGFILE%" 2>&1
set RC=%ERRORLEVEL%
echo [%date% %time%] run.py ExitCode=%RC% >> "%LOGFILE%"

if %RC% NEQ 0 (
    echo [HATA] Tahmin motoru basarisiz - SQL baglantisi / run.py log'una bak. >> "%LOGFILE%"
)
exit /b %RC%
