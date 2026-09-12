/* ============================================================================
   SEMA METRİK KAYITLARI — İŞARETÇİ DENETİMİ  (2026-09-12)
   ⚠ BU DOSYA SQL DEĞİL, BİR DENETİM KAYDIDIR. Ölçüm DB'de değil DOSYA SİSTEMİNDE
     yapıldı; buraya yöntem + sonuç yazılıyor ki yeniden koşturulabilsin.

   NEDEN: `metrics` dosyasında 75 kayıtta `evidence` yoktu. Entities'te kanıt
   "kolonlar canlıda var mı" ile, bridges'te "öksüz ölçümü" ile, codes'ta "canlı
   GROUP BY" ile üretilebildi. METRİKLERDE BÖYLE BİR TEK-ATIŞ KANIT YOK: bir
   formülün DOĞRU olduğunu göstermek, o formülü koşturup bağımsız bir kaynakla
   mutabakat yapmak demektir ve bu 127 kayıt için tek tek yapılacak iştir.

   ⚠ BU YÜZDEN ŞABLON KANIT YAZILMADI. 75 kayda tek tip bir cümle yazmak sayacı
     sıfırlardı ve sorunu GİZLERDİ. Onun yerine her kayda O KAYIT İÇİN ÖLÇÜLEN
     şey yazıldı: uygulaması bulunabiliyor mu?

   ============================================================================
   YÖNTEM (yeniden koşturulabilir)
   ============================================================================
   1. `sema/metrics.yaml` okunur; her kaydın `applied_in` · `source` · `note`
      alanlarındaki metin birleştirilir.
   2. Metinden dosya adı deseni çıkarılır:  [\w\-./\\]+\.(sql|cs|py|razor)
   3. Her aday için: repo kökünde var mı? Yoksa aynı basename repo'da başka yerde
      var mı? İkisi de değilse KIRIK sayılır.
      ⚠ TUZAK (yaşandı): regex BOŞLUKTA BÖLER. `applied_in: "DEPO ÖZET DURUM.sql"`
        → `DURUM.sql` diye "kırık" görünür. 4 kayıt böyle yanlış alarm verdi;
        elle bakılınca hepsinin repo DIŞI (D:/Belgelerim/sql) dosyalar olduğu görüldü.
        Ders: desen eşleşmesinden çıkan "kırık" listesi TEYİT EDİLMEDEN rapor edilmez.

   ============================================================================
   SONUÇ — 127 metrik kaydı
   ============================================================================
     16  repo içi dosyaya işaret ediyor, İŞARETÇİLER ÇÖZÜLÜYOR
      4  repo DIŞI dosya gösteriyor (D:/Belgelerim/sql — sürümlenmemiş)
                 depo_stok_dagilim · wms_bekleyen_toplama ·
                 cari_firma_stok_hareket · il_teslimat_perf
    107  HİÇBİR uygulama dosyasına işaret ETMİYOR

   ⇒ `semantic-layer.md` § KEŞİF SQL'İ ARŞİVLE (ikiz yükümlülük) metrics tarafında
     UYGULANMAMIŞ. "Bu metrik nerede hesaplanıyor?" sorusunun cevabı 107 kayıtta YOK.

   ⚠⚠ `sema denetle` artık `kanit_yok: 0` diyor (185 → 0). BU, METRİKLERİN
      DOĞRULANDIĞI ANLAMINA GELMEZ. Hiçbir formül koşturulmadı. Sayacın sıfırlanması
      yalnız "her kayıt kendi kanıt durumunu BEYAN ediyor" demektir.
      Kalıcı uyarı: `metrics:_metrik_kanit_durumu_2026_09_12`.

   ============================================================================
   TEK TEK KAPATMA YOLU (her metrik için)
   ============================================================================
   1. Metriği hesaplayan sorguyu yaz/bul, `sorgular/YYYY-MM-DD-<konu>.sql` altına arşivle.
   2. Kaydın `applied_in` alanını o dosyaya bağla.
   3. Sorguyu KOŞTUR; çıkan rakamı bağımsız bir kaynakla (başka bir hesap yolu,
      muhasebe, POS) karşılaştır.
   4. Sonucu TARİHİYLE `evidence` alanına yaz: "<tarih> — <sorgu> koştu: <rakam>;
      <bağımsız kaynak> ile %<sapma> içinde tuttu."
   5. Kapanan her kayıt `_metrik_kanit_durumu_2026_09_12` kaydındaki 107 sayısını düşürür.
*/
