@echo off
REM BKM Haftalik Muhasebe Denetimi - rapor uret + mail gonder.
REM Task Scheduler "BKM-Muhasebe-Denetim" (Pazartesi 08:00) bunu cagirir.
REM Manuel test: send_muhasebe_denetim.bat
setlocal
cd /d D:\Dev\pusula

set "PYCMD=python"
where python >nul 2>&1 || set "PYCMD=C:\Python313\python.exe"

REM 1) Rapor uret (SALT-OKUMA SP). Hata olursa mail atma.
"%PYCMD%" scripts\haftalik_muhasebe_denetim.py
if errorlevel 1 (
    echo Rapor uretilemedi, mail atlanir.
    exit /b 1
)

REM 2) Mail gonder (brief ile ayni SMTP config + aliciler).
"%PYCMD%" scripts\send_mail.py --to fikrieren@gmail.com fikri.eren@bkmkitap.com ^
    --subject "BKM Kitap - Haftalik Muhasebe Denetimi" ^
    --html "raporlar\denetim\muhasebe-denetim.html" ^
    --config .secrets\smtp.json
endlocal
