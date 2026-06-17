namespace GmDashboard.Data;

/// <summary>BKM mağaza/lokasyon sabitleri. ehMekan IN (Subeler) veya IN (SubelerVeDepo) olarak SQL'e gömülür.</summary>
public static class LokasyonConfig
{
    // FSM=1, Özlüce=4477, İstanbul Yolu=4478
    public const string Subeler = "1,4477,4478";
    // Şubeler + Merkez Depo 12
    public const string SubelerVeDepo = "12,1,4478,4477";
}
