@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

echo Sepet Büyüklüğü Etkisi Dashboard - Excel Dosyası Oluşturucu
echo ============================================================
echo.

REM Python'u bul
python --version >nul 2>&1
if errorlevel 1 (
    echo Hata: Python kurulu değil veya PATH'ta yok.
    pause
    exit /b 1
)

REM openpyxl yükle
echo openpyxl kontrol ediliyor...
python -m pip list | find /i "openpyxl" >nul
if errorlevel 1 (
    echo openpyxl kurulumu yapılıyor...
    python -m pip install openpyxl -q
    if errorlevel 1 (
        echo Hata: openpyxl kurulamadı.
        pause
        exit /b 1
    )
)

echo openpyxl hazır.
echo.

REM Script'i çalıştır
echo Excel dosyası oluşturuluyor...
python "%~dp0generate_excel.py"

if errorlevel 1 (
    echo.
    echo Hata oluştu!
    pause
    exit /b 1
)

echo.
echo Başarılı!
pause
exit /b 0
