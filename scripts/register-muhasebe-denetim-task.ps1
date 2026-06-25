# Windows Task Scheduler'a "BKM-Muhasebe-Denetim" gorevini kaydeder.
# Her Pazartesi 08:00'de send_muhasebe_denetim.bat tetiklenir:
#   -> haftalik_muhasebe_denetim.py (kapanis-sonrasi mudahale raporu, SALT-OKUMA SP)
#   -> send_mail.py (HTML mail).
# YEREL calisir (LAN DB 192.168.40.201'e erisim icin sart; bulut/headless ulasamaz).
# ASCII-only (Windows PowerShell 5.1 BOM'suz UTF-8 Turkce'yi bozar).
#
# Kullanim:  cd D:\Dev\pusula ;  .\scripts\register-muhasebe-denetim-task.ps1
# Silmek:    Unregister-ScheduledTask -TaskName "BKM-Muhasebe-Denetim" -Confirm:$false

$taskName = "BKM-Muhasebe-Denetim"
$batPath = "D:\Dev\pusula\send_muhasebe_denetim.bat"
$workingDir = "D:\Dev\pusula"

if (-not (Test-Path $batPath)) {
    Write-Host "HATA: $batPath bulunamadi" -ForegroundColor Red
    exit 1
}

$existing = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($existing) {
    Write-Host "Mevcut gorev bulundu, kaldiriliyor (idempotent)..." -ForegroundColor Yellow
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
}

$action = New-ScheduledTaskAction -Execute "cmd.exe" -Argument "/c `"$batPath`"" -WorkingDirectory $workingDir
$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday -At "08:00"
$principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Limited
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -DontStopOnIdleEnd `
    -ExecutionTimeLimit (New-TimeSpan -Hours 1)

Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger `
    -Settings $settings -Principal $principal `
    -Description "BKM haftalik muhasebe denetimi (kapanis-sonrasi mudahale) - Pazartesi 08:00, rapor+mail" | Out-Null

Write-Host "OK: '$taskName' kaydedildi (her Pazartesi 08:00)." -ForegroundColor Green
Write-Host "Hemen test: Start-ScheduledTask -TaskName '$taskName'" -ForegroundColor Gray
