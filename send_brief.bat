@echo off
REM BKM Kitap - Pazartesi Brifingi SMTP gonderim tetikleyicisi
REM v4 - Tarih DINAMIK: bugunun tarihine en yakin Pazartesi'yi bulur.
REM      Boylece Windows Task Scheduler ile her Pazartesi otomatik calisir.

setlocal enabledelayedexpansion
cd /d "%~dp0"

set LOGFILE=%~dp0send_brief.log
echo [%date% %time%] Basladi > "%LOGFILE%"
echo [%date% %time%] CWD: %CD% >> "%LOGFILE%"

REM ===========================================================
REM Bugunun tarihinden bu haftanin Pazartesi'sini hesapla.
REM PowerShell ile: (Get-Date).AddDays(-((Get-Date).DayOfWeek - 1))
REM Format: YYYY-MM-DD ve DD.MM.YYYY
REM ===========================================================

for /f "usebackq delims=" %%D in (`powershell -NoProfile -Command "(Get-Date).AddDays(-( ([int](Get-Date).DayOfWeek + 6) %% 7 )).ToString('yyyy-MM-dd')"`) do set "MONDAY_ISO=%%D"
for /f "usebackq delims=" %%D in (`powershell -NoProfile -Command "(Get-Date).AddDays(-( ([int](Get-Date).DayOfWeek + 6) %% 7 )).ToString('dd.MM.yyyy')"`) do set "MONDAY_DMY=%%D"

echo [%date% %time%] Pazartesi tarihi: %MONDAY_ISO% (%MONDAY_DMY%) >> "%LOGFILE%"

set "BRIEF_DIR=briefings\%MONDAY_ISO%"
set "BRIEF_HTML=%BRIEF_DIR%\brief.html"
set "BRIEF_TXT=%BRIEF_DIR%\brief.txt"

if not exist "%BRIEF_HTML%" (
    echo [HATA] Brief HTML bulunamadi: %BRIEF_HTML% >> "%LOGFILE%"
    echo [HATA] Bu haftanin briefingi henuz uretilmemis. >> "%LOGFILE%"
    exit /b 3
)

REM ===========================================================
REM Python bul
REM ===========================================================

set "PYCMD="

REM 1) PATH'taki python.exe (gercekten var mi kontrol)
for /f "delims=" %%P in ('where python 2^>nul') do (
    if not defined PYCMD (
        if exist "%%P" (
            set "PYCMD=%%P"
            echo [%date% %time%] PATH python: %%P >> "%LOGFILE%"
        )
    )
)

REM 2) py launcher - GERCEK python.exe'yi sys.executable ile bul
if not defined PYCMD (
    for %%V in (3.13 3.12 3.11 3.10 3) do (
        if not defined PYCMD (
            for /f "delims=" %%P in ('py -%%V -c "import sys; print(sys.executable)" 2^>nul') do (
                if exist "%%P" (
                    set "PYCMD=%%P"
                    echo [%date% %time%] py -%%V: %%P >> "%LOGFILE%"
                )
            )
        )
    )
)

REM 3) Bilinen kurulum konumlari
if not defined PYCMD (
    for %%P in (
        "C:\Python313\python.exe"
        "C:\Python312\python.exe"
        "C:\Python311\python.exe"
        "C:\Python310\python.exe"
        "%LOCALAPPDATA%\Programs\Python\Python313\python.exe"
        "%LOCALAPPDATA%\Programs\Python\Python312\python.exe"
        "%LOCALAPPDATA%\Programs\Python\Python311\python.exe"
        "%LOCALAPPDATA%\Programs\Python\Python310\python.exe"
        "%ProgramFiles%\Python313\python.exe"
        "%ProgramFiles%\Python312\python.exe"
    ) do (
        if not defined PYCMD (
            if exist %%P (
                set "PYCMD=%%~P"
                echo [%date% %time%] Fixed path: %%~P >> "%LOGFILE%"
            )
        )
    )
)

if not defined PYCMD (
    echo [HATA] Calisabilir Python bulunamadi >> "%LOGFILE%"
    exit /b 2
)

echo [%date% %time%] Kullanilacak: "%PYCMD%" >> "%LOGFILE%"
"%PYCMD%" --version >> "%LOGFILE%" 2>&1

REM ===========================================================
REM Mail gonder
REM ===========================================================

if exist "%BRIEF_TXT%" (
    "%PYCMD%" scripts\send_mail.py --to fikrieren@gmail.com fikri.eren@bkmkitap.com --subject "BKM Kitap - Pazartesi Brifingi - %MONDAY_DMY%" --html "%BRIEF_HTML%" --text "%BRIEF_TXT%" --config .secrets\smtp.json >> "%LOGFILE%" 2>&1
) else (
    "%PYCMD%" scripts\send_mail.py --to fikrieren@gmail.com fikri.eren@bkmkitap.com --subject "BKM Kitap - Pazartesi Brifingi - %MONDAY_DMY%" --html "%BRIEF_HTML%" --config .secrets\smtp.json >> "%LOGFILE%" 2>&1
)

set RC=%ERRORLEVEL%
echo [%date% %time%] ExitCode=%RC% >> "%LOGFILE%"
exit /b %RC%
