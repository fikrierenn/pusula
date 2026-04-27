@echo off
REM MCP Config Fix - Wrapper
REM Cift tikla calistir, ekrani kapatma

echo ===============================================
echo   MCP Config Fix - SQL Server Baglanti Duzeltme
echo ===============================================
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0fix-mcp-config.ps1"

echo.
echo ===============================================
echo   Script tamamlandi (basarili veya hatali).
echo ===============================================
echo.
pause
