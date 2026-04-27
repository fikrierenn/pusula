# SsmsExcelExporter — SSMS External Tool Kurulumu

## 1. Build

Komut satırında proje klasörüne git ve yayınla:

```
cd D:\Dev\sqlserver-mcp-server\sorgular\03-kampanya\SsmsExcelExporter
dotnet publish -c Release -r win-x64
```

EXE burada oluşacak:
```
bin\Release\net8.0-windows\win-x64\publish\SsmsExcelExporter.exe
```

## 2. SSMS'e External Tool Olarak Ekle

1. SSMS'i aç
2. Menüden: **Tools → External Tools...**
3. Açılan pencerede **Add** butonuna tıkla
4. Şunları doldur:

| Alan | Değer |
|------|-------|
| **Title** | `Excel Export` |
| **Command** | `D:\Dev\sqlserver-mcp-server\sorgular\03-kampanya\SsmsExcelExporter\bin\Release\net8.0-windows\win-x64\publish\SsmsExcelExporter.exe` |
| **Arguments** | _(boş bırak)_ |
| **Initial directory** | _(boş bırak)_ |

5. **OK** tıkla

## 3. Kullanım

1. SSMS'te sorguyu çalıştır
2. Sonuç grid'inde **Ctrl+A** (tümünü seç) → **Ctrl+C** (kopyala)
3. Menüden **Tools → Excel Export** tıkla
4. Açılan pencerede **Clipboard'dan Yapıştır** butonuna tıkla (veya Ctrl+V)
5. Ayarları yap (gruplama kolonu, alt toplam, renk vs.)
6. **EXCEL OLUŞTUR** tıkla → Excel açılır

## 4. Kısayol Tuşu (Opsiyonel)

SSMS'te Tools altında eklenen araçlar sırayla numaralanır.
Eğer "Excel Export" 1. sıradaysa: **Alt+T, 1** ile çalıştırabilirsin.
Sırayı değiştirmek için Tools > External Tools penceresinde yukarı/aşağı ok butonlarını kullan.

## Notlar

- .NET 8 Runtime gerekli (runtime yoksa: https://dotnet.microsoft.com/download/dotnet/8.0)
- SSMS grid'den kopyalanan veri tab-separated + header formatındadır
- Türkçe sayı formatı (1.234,56) otomatik tanınır
