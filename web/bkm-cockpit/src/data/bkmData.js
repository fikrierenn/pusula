export const BKM_DETAILED_DATA = {
  summary: {
    gross_total: 105822956.40,
    net_total: 92348512.10,
    receipt_count: 153376,
    avg_basket: 690.0,
    product_count: 526840,
    season_period: "01.08.2026 - 30.09.2026",
    active_stores: 3,
    avg_gross_margin: 43.8,
    victories: [
      { title: "Çanta Fiili Marjı %53.5", desc: "%50 indirime rağmen toptan giriş maliyetleriyle 4.52M ₺ net brüt kâr sağlandı." },
      { title: "3 Al 2 Öde Sepet Kaldıracı", desc: "Kampanyalı fişlerde ortalama sepet 2.297 ₺'ye sıçradı (genelin 3.3 katı)." },
      { title: "Kırtasiye Satış Dominansı", desc: "55.5M ₺ ciro ve 300K+ adet ürünle toplam cironun %52.5'ini sırtladı." }
    ],
    alarms: [
      { title: "MEB Maarif Batık Stoku", desc: "1. ve 5. sınıflarda depoda kalan 15.661 adet kitap (3.44M ₺ bağlı nakit riski)." },
      { title: "İstanbul Yolu Negatif Büyüme", desc: "İstanbul Yolu perakende cirosu -%4.5 geriledi, envanter açığı ve raf boşluğu var." }
    ],
    opportunity: {
      title: "Masada Bırakılan 6.2M ₺ Gece Cirosu",
      desc: "Saat 20:00-23:00 arasında oluşan kasa kuyruklarında terk edilen sepet oranı tahmini %8.5. 2 mobil POS ile anında geri kazanılabilir."
    }
  },
  stores: [
    {
      id: "FSM",
      name: "FSM Mağazası",
      code: "M01",
      gross: 51240180.20,
      net: 44810200.00,
      receipts: 71420,
      basket: 717.45,
      items_per_basket: 3.65,
      growth: "+14.2%",
      margin: 44.8,
      status: "Lider Şube",
      color: "#14B8A6",
      top_category: "Kitap & Kafe & Lüks Kırtasiye",
      strengths: "Yüksek sepet ortalaması (717 ₺), güçlü müşteri sadakati, hafta sonu yoğun aile akışı.",
      weaknesses: "Pik saatlerde (20:00-22:00) kasa kuyrukları ve çanta reyonunda alan darlığı.",
      hourly_peak: "21:00 (1.420 Fiş)",
      cash_registers: 6,
      stock_health: "94.2%"
    },
    {
      id: "OZLUCE",
      name: "Özlüce Mağazası",
      code: "M02",
      gross: 38115420.70,
      net: 33190450.50,
      receipts: 58310,
      basket: 653.67,
      items_per_basket: 3.25,
      growth: "+9.8%",
      margin: 43.2,
      status: "Büyüme Odağı",
      color: "#3B82F6",
      top_category: "Okul Kırtasiyesi & Çanta",
      strengths: "Nilüfer okul kuşağına yakınlık, en yüksek çanta adet satışı, 3 Al 2 Öde penetrasyonu.",
      weaknesses: "Kültür kitabı satışlarının toplam cirodaki payının FSM'ye göre düşük kalması.",
      hourly_peak: "21:00 (1.290 Fiş)",
      cash_registers: 5,
      stock_health: "91.8%"
    },
    {
      id: "IST_YOLU",
      name: "İstanbul Yolu",
      code: "M03",
      gross: 16467355.50,
      net: 14347861.60,
      receipts: 23646,
      basket: 696.41,
      items_per_basket: 3.82,
      growth: "-4.5%",
      margin: 39.5,
      status: "Dönüşüm Gerekiyor",
      color: "#F59E0B",
      top_category: "Sınav Hazırlık & Lojistik",
      strengths: "Merkez depoya entegre toptan/kurumsal işlemler, yüksek adetli sepetler.",
      weaknesses: "Perakende yaya trafiği zayıf, raf envanteri uyumsuzlukları ve Maarif daralması.",
      hourly_peak: "19:00 (290 Fiş)",
      cash_registers: 3,
      stock_health: "78.4%"
    }
  ],
  categories: [
    { name: "Kırtasiye & Okul", share: 52.5, revenue: 55557052, margin: 46.2, color: "#14B8A6", unitSales: 312400 },
    { name: "Kitap (Kültür/Sınav)", share: 33.4, revenue: 35344867, margin: 38.5, color: "#3B82F6", unitSales: 168200 },
    { name: "Oyuncak & Hobi", share: 8.2, revenue: 8677482, margin: 48.0, color: "#8B5CF6", unitSales: 24500 },
    { name: "Çanta & Beslenme", share: 8.0, revenue: 8440000, margin: 53.5, color: "#EC4899", unitSales: 10550 },
    { name: "Kafe & Diğer", share: 5.9, revenue: 6243554, margin: 62.0, color: "#F59E0B", unitSales: 11190 }
  ],
  sku_matrix: {
    winners: [
      { name: "Faber-Castell 12'li Boya Seti", cat: "Kırtasiye", sold: 18450, rev: "1.47M ₺", margin: "48%", reason: "Okul listelerinin 1 numaralı değişmez SKU'su" },
      { name: "Gıpta Spiralli Defter Serisi", cat: "Kırtasiye", sold: 42100, rev: "2.10M ₺", margin: "52%", reason: "3 Al 2 Öde sepetlerinde ana tetikleyici" },
      { name: "Kral Şakir Yeni Macera (Kitap)", cat: "Çocuk Kitap", sold: 12400, rev: "992K ₺", margin: "42%", reason: "Kasa yanı dürtüsel sepete ekleme şampiyonu" },
      { name: "Yaygan İlkokul Sırt Çantası", cat: "Çanta", sold: 4200, rev: "3.36M ₺", margin: "56%", reason: "%50 indirimle en hızlı tükenen çanta SKU'su" }
    ],
    losers: [
      { name: "5. Sınıf Eski Müfredat Türkçe SB", cat: "Sınav Kitap", stock: 6420, tied: "1.41M ₺", alert: "Maarif Modeli dışı kaldı, satış -%88 düştü" },
      { name: "1. Sınıf Eski Okuma Yazma Seti", cat: "Okul Öncesi", stock: 9241, tied: "2.03M ₺", alert: "Bakanlık yeni seti zorunlu tuttu, depoda kilitli" },
      { name: "İthal Lüks Kalemlik Serisi", cat: "Aksesuar", stock: 1840, tied: "460K ₺", alert: "Yüksek fiyat direnci (850 ₺), raf devir hızı 0.12" }
    ]
  },
  hourly_traffic: [
    { hour: "10:00", FSM: 120, OZLUCE: 95, IST_YOLU: 45 },
    { hour: "12:00", FSM: 280, OZLUCE: 210, IST_YOLU: 110 },
    { hour: "14:00", FSM: 450, OZLUCE: 390, IST_YOLU: 180 },
    { hour: "16:00", FSM: 620, OZLUCE: 540, IST_YOLU: 210 },
    { hour: "18:00", FSM: 890, OZLUCE: 750, IST_YOLU: 240 },
    { hour: "20:00", FSM: 1250, OZLUCE: 1080, IST_YOLU: 290 },
    { hour: "21:00", FSM: 1420, OZLUCE: 1290, IST_YOLU: 260 },
    { hour: "22:00", FSM: 980, OZLUCE: 810, IST_YOLU: 140 }
  ]
};

export const BKM_DATA = BKM_DETAILED_DATA;
