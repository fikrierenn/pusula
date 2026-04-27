@echo off
REM BKM Kitap - Pazartesi Brifingi SMTP gonderim tetikleyicisi
REM v3 - python yolu gercekten var mi diye dogrular, py launcher'in stale
REM kaydini (C:\Python313\python.exe yok) atlatir.

setlocal enabledelayedexpansion
cd /d "%~dp0"

set LOGFILE=%~dp0send_brief.log
echo [%date% %time%] Basladi > "%LOGFILE%"
echo [%date% %time%] CWD: %CD% >> "%LOGFILE%"

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

"%PYCMD%" scripts\send_mail.py --to fikrieren@gmail.com fikri.eren@bkmkitap.com --subject "BKM Kitap - Pazartesi Brifingi - 20.04.2026" --html briefings\2026-04-20\brief.html --text briefings\2026-04-20\brief.txt --config .secrets\smtp.json >> "%LOGFILE%" 2>&1

set RC=%ERRORLEVEL%
echo [%date% %time%] ExitCode=%RC% >> "%LOGFILE%"
exit /b %RC%
