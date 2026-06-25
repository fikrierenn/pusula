namespace GmDashboard.Models;

/// <summary>ODAK stok-satış paneli (B-122). Kaynak: ent.odak_depo_Stok (kanonik ODAK fulfillment stoğu) +
/// irsHrk şube satış + OPENQUERY(ODAKJOKER) e-ticaret + fat alış (usulsüz tespiti). Dünkü Excel raporunun panel hali.</summary>

/// <summary>Kategori seçici satırı (ODAK stoklu kategoriler).</summary>
public record OdakKategori(string Kategori, int Cesit, int StokAdet);

/// <summary>Marka/yayınevi özeti (seçili kategori) — çeşit, stok, ciro, devir.</summary>
public record OdakMarkaOzet(string Marka, int Cesit, int StokAdet, int YilSatis, decimal YilCiro, decimal? Devir);

/// <summary>Ürün tam döküm satırı (seçili kategori, sayfalı) — şube/depo/ODAK stok + satış + maliyet/fiyat.</summary>
public record OdakUrun(
    int StkID, string Marka, string? Yazar, string Kod, string Urun,
    int StokFsm, int StokOzl, int StokIst, int StokMrkz, int StokOdak, int StokToplam,
    int SatisFsm, int SatisOzl, int SatisIst, int EcomSiparis, int SatisToplam,
    decimal? Maliyet, decimal? Fiyat, decimal? AyKapsam);

/// <summary>Usulsüz sipariş satırı — ODAK stoğu yüksekken (veya satışsız) farklı carilerden alım yapılan ürün.</summary>
public record OdakUsulsuz(
    int StkID, string Marka, string Kod, string Urun,
    int OdakStok, int YilSatis, decimal? AyKapsam,
    int CariSayisi, int FaturaSayisi, int AlisAdet, decimal AlisTutar);

/// <summary>Usulsüz drill — bir ürünün cari bazlı alış kırılımı (modal). CariId = frmID (fatura drill için).</summary>
public record OdakUsulsuzCari(int CariId, string CariKod, string CariAd, int FaturaSayisi, decimal AlisAdet, decimal AlisTutar, string SonAlis);

/// <summary>Cari × ürün fatura kırılımı (cari satırına tıklayınca) — eID ile /fatura sayfasına link.</summary>
public record OdakCariFatura(int EID, string EvrakNo, string Tarih, decimal Adet, decimal Tutar);

/// <summary>Sayfalı sonuç sarmalayıcı (server-side OFFSET/FETCH).</summary>
public record OdakSayfa<T>(IReadOnlyList<T> Satirlar, int ToplamSatir);
