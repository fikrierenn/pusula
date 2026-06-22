namespace GmDashboard.Data;

/// <summary>
/// Tek Düzen Hesap Planı 3-haneli ana hesap adları (mizan ağacı üst seviye etiketi).
/// mhsHsp yalnız noktalı alt hesapları (100.10, 100.10.001) tutar; 3-haneli ana hesap adı (Kasa/Bankalar)
/// ulusal standart → buradan. Kaynak: BKM 2025 kesin mizan (Tek Düzen). Eksik kod → kodun kendisi gösterilir.
/// </summary>
public static class TekDuzenHesap
{
    public static readonly IReadOnlyDictionary<string, string> Ad = new Dictionary<string, string>
    {
        ["100"] = "Kasa", ["101"] = "Alınan Çekler", ["102"] = "Bankalar",
        ["103"] = "Verilen Çekler ve Ödeme Birimleri", ["108"] = "Diğer Hazır Değerler",
        ["120"] = "Alıcılar", ["121"] = "Alacak Senetleri", ["126"] = "Verilen Depozito ve Teminatlar",
        ["135"] = "Personelden Alacaklar", ["136"] = "Diğer Çeşitli Alacaklar",
        ["150"] = "İlk Madde ve Malzeme", ["153"] = "Ticari Mallar", ["159"] = "Verilen Sipariş Avansları",
        ["180"] = "Gelecek Aylara Ait Giderler", ["190"] = "Devreden Katma Değer Vergisi",
        ["191"] = "İndirilecek KDV", ["193"] = "Peşin Ödenen Vergiler ve Fonlar", ["195"] = "İş Avansları",
        ["196"] = "Personel Avansları", ["197"] = "Sayım ve Tesellüm Noksanları",
        ["226"] = "Verilen Depozito ve Teminatlar", ["252"] = "Binalar", ["253"] = "Tesis,Makina ve Cihazlar",
        ["254"] = "Taşıtlar", ["255"] = "Demirbaşlar", ["257"] = "Birikmiş Amortismanlar(-)",
        ["260"] = "Haklar", ["264"] = "Özel Maliyetler", ["267"] = "Diğer Maddi Olmayan Duran Varlıklar",
        ["268"] = "Birikmiş Amortismanlar(-)", ["280"] = "Gelecek Yıllara Ait Giderler",
        ["300"] = "Banka Kredileri", ["309"] = "Diğer Mali Borçlar", ["320"] = "Satıcılar",
        ["321"] = "Borç Senetleri", ["329"] = "Diğer Ticari Borçlar", ["331"] = "Ortaklara Borçlar",
        ["335"] = "Personele Borçlar", ["340"] = "Alınan Sipariş Avansları", ["360"] = "Ödenecek Vergi ve Fonlar",
        ["361"] = "Ödenecek Sosyal Güvenlik Kesintileri", ["369"] = "Ödenecek Diğer Yükümlülükler",
        ["370"] = "Dönem Karı ve Diğer Yasal Yükümlülük Karşılıkları",
        ["371"] = "Dönem Karının Peşin Ödenen Vergi ve Diğer Yükümlülükleri",
        ["381"] = "Gider Tahakkukları", ["391"] = "Hesaplanan KDV", ["397"] = "Sayım ve Tesellüm Fazlaları",
        ["400"] = "Banka Kredileri", ["500"] = "Sermaye", ["502"] = "Sermaye Düzeltmesi Olumlu Farkları",
        ["540"] = "Yasal Yedekler", ["570"] = "Geçmiş Yıllar Karları", ["590"] = "Dönem Net Karı",
        ["600"] = "Yurtiçi Satışlar", ["602"] = "Diğer Gelirler", ["610"] = "Satıştan İadeler(-)",
        ["621"] = "Satılan Ticari Mallar Maliyeti(-)", ["622"] = "Satılan Hizmet Maliyeti(-)",
        ["631"] = "Pazarlama Satış ve Dağıtım Giderleri", ["632"] = "Genel Yönetim Giderleri",
        ["642"] = "Faiz Gelirleri", ["653"] = "Komisyon Giderleri", ["656"] = "Kambiyo Zararları",
        ["660"] = "Kısa Vadeli Borçlanma Giderleri", ["679"] = "Diğer Olağandışı Gelir ve Karlar",
        ["689"] = "Diğer Olağandışı Gider ve Zararlar", ["690"] = "Dönem Karı veya Zararı",
        ["691"] = "Dönem Karı Vergi ve Diğer Yasal Yükümlülük Karşılıkları(-)",
        ["692"] = "Dönem Net Karı veya Zararı", ["740"] = "Hizmet Üretim Maliyeti",
        ["741"] = "Hizmet Üretim Maliyeti Yansıtma Hesabı", ["760"] = "Pazarlama,Satış ve Dağıtım Giderleri",
        ["761"] = "Pazarlama,Satış ve Dağıtım Giderleri Yansıtma Hesabı", ["770"] = "Genel Yönetim Giderleri",
        ["771"] = "Genel Yönetim Giderleri Yansıtma Hesabı", ["780"] = "Finansman Giderleri",
        ["781"] = "Finansman Giderleri Yansıtma Hesabı",
        ["950"] = "Kanunen Kabul Edilmeyen Giderler ve Matraha Eklenecek Diğer Tutarlar",
        ["951"] = "Matraha Eklenecek Tutarlar Alacaklı Hesabı",
    };

    public static string AdVeya(string kod) => Ad.TryGetValue(kod, out var a) ? a : kod;
}
