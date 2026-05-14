# ============================================================
# DEPRECATED — bu gorev artik kullanilmiyor.
# ============================================================
# Eskiden iki ayri Task Scheduler gorevi vardi:
#   - BKM-Brief-Generator          (Pazar 23:30 + Pzt 06:00) -> brief.html uretir
#   - BKM-Kitap-Pazartesi-Brifingi (Pzt 09:00)               -> maili gonderir
#
# Bilgisayar Pazar gecesi/Pazartesi sabahi kapaliysa, StartWhenAvailable
# yuzunden ikisi de acilista ayni anda tetikleniyor; gonderici brief.html'i
# bulamayip "uretilmemis" diye cikiyordu (11.05.2026'da bu yasandi).
#
# COZUM: send_brief.bat v5 self-healing — brief.html yoksa generate_brief.py
# ile kendisi uretir, sonra gonderir. Artik TEK gorev yeterli:
#   scripts\register-scheduled-task.ps1  -> BKM-Kitap-Pazartesi-Brifingi
#
# Bu script artik sadece eski generator gorevini KALDIRMAK icin duruyor.
# ============================================================

$taskName = "BKM-Brief-Generator"

$existing = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($existing) {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    Write-Host "OK: Eski '$taskName' gorevi kaldirildi (artik gereksiz)." -ForegroundColor Green
} else {
    Write-Host "Bilgi: '$taskName' gorevi zaten yok, yapilacak bir sey yok." -ForegroundColor Gray
}

Write-Host ""
Write-Host "Brief uretimi + gonderimi artik TEK gorevde:" -ForegroundColor Cyan
Write-Host "  .\scripts\register-scheduled-task.ps1" -ForegroundColor White
Write-Host "  -> BKM-Kitap-Pazartesi-Brifingi (her Pazartesi 09:00, send_brief.bat)" -ForegroundColor Gray
Write-Host ""
