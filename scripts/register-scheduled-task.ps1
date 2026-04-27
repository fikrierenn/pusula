# Windows Task Scheduler'a "BKM-Kitap-Pazartesi-Brifingi" gorevini kayit eder.
# Her Pazartesi sabah 09:00'da send_brief.bat tetiklenir.
#
# Kullanim (yonetici PowerShell gerekmez):
#   cd D:\Dev\sqlserver-mcp-server
#   .\scripts\register-scheduled-task.ps1
#
# Silmek icin:
#   Unregister-ScheduledTask -TaskName "BKM-Kitap-Pazartesi-Brifingi" -Confirm:$false

$taskName = "BKM-Kitap-Pazartesi-Brifingi"
$batPath = "D:\Dev\sqlserver-mcp-server\send_brief.bat"
$workingDir = "D:\Dev\sqlserver-mcp-server"

if (-not (Test-Path $batPath)) {
    Write-Host "HATA: $batPath bulunamadi" -ForegroundColor Red
    exit 1
}

# Mevcut gorev varsa onceden kaldir (idempotent)
$existing = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($existing) {
    Write-Host "Mevcut gorev bulundu, kaldiriliyor..." -ForegroundColor Yellow
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
}

# Action: bat dosyasini calistir
$action = New-ScheduledTaskAction `
    -Execute "cmd.exe" `
    -Argument "/c `"$batPath`"" `
    -WorkingDirectory $workingDir

# Trigger: her Pazartesi 09:00
$trigger = New-ScheduledTaskTrigger `
    -Weekly `
    -DaysOfWeek Monday `
    -At "09:00"

# Principal: mevcut kullanici, oturum acikken calissin
$principal = New-ScheduledTaskPrincipal `
    -UserId "$env:USERDOMAIN\$env:USERNAME" `
    -LogonType Interactive `
    -RunLevel Limited

# Settings:
#  - StartWhenAvailable: bilgisayar kapaliysa acildiginda hemen calistir
#  - AllowStartIfOnBatteries: batarya modunda calissin
#  - DontStopIfGoingOnBatteries: bataryaya gecince durmasin
$settings = New-ScheduledTaskSettingsSet `
    -StartWhenAvailable `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 5)

# Kayit
Register-ScheduledTask `
    -TaskName $taskName `
    -Description "BKM Kitap Pazartesi Brifingi - haftalik mail gonderim (send_brief.bat)" `
    -Action $action `
    -Trigger $trigger `
    -Principal $principal `
    -Settings $settings | Out-Null

Write-Host ""
Write-Host "OK: '$taskName' Task Scheduler'a kayit edildi" -ForegroundColor Green
Write-Host ""
Write-Host "Detay:" -ForegroundColor Cyan
Get-ScheduledTask -TaskName $taskName | Format-List TaskName, State, Author, Description
Write-Host ""
Write-Host "Triggerlar:" -ForegroundColor Cyan
(Get-ScheduledTask -TaskName $taskName).Triggers | Format-List
Write-Host ""
Write-Host "Manuel test (simdi calistir):" -ForegroundColor Gray
Write-Host "  Start-ScheduledTask -TaskName '$taskName'" -ForegroundColor Gray
Write-Host ""
Write-Host "Son calismayi gor:" -ForegroundColor Gray
Write-Host "  Get-ScheduledTask -TaskName '$taskName' | Get-ScheduledTaskInfo" -ForegroundColor Gray
Write-Host ""
Write-Host "Kaldir:" -ForegroundColor Gray
Write-Host "  Unregister-ScheduledTask -TaskName '$taskName' -Confirm:`$false" -ForegroundColor Gray
Write-Host ""
