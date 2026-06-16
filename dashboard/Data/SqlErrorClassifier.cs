using Microsoft.Data.SqlClient;

namespace GmDashboard.Data;

/// <summary>
/// Merkezi SQL hata sınıflandırıcı (plan-12 WS-5 — Hermes error_classifier uyarlaması).
/// Dağınık inline string-match yerine TEK kaynak: transient (retry) vs fatal (fail).
/// BKM tek-DB/tek-JOKER → Hermes'in should_rotate/should_fallback flag'leri YOK; sadece should_retry.
/// </summary>
public enum SqlErrorKind { Transient, Fatal }

public static class SqlErrorClassifier
{
    // Geçici (retry-edilebilir) SQL error number'ları: timeout, ağ kopması, deadlock, failover.
    // Kaynak: SQL Server transient-fault rehberi + yerel gözlem (server restart → 53/-2, SignalR-drop senaryosu).
    private static readonly HashSet<int> Transient = new()
    {
        -2,            // komut/bağlantı timeout (CommandTimeout/ConnectTimeout)
        -1, 2, 53,     // bağlantı kurulamadı / ağ yolu yok (server restart/blip)
        20, 64, 233,   // bağlantı koptu / pipe ucu yok
        10053, 10054, 10060,  // socket reset/refused/timeout
        1205,          // deadlock kurbanı
        4060,          // veritabanı açılamadı (failover sırasında geçici)
        40197, 40501, 40613, 49918, 49919, 49920,  // (Azure throttle/unavailable — zararsız ek)
    };

    // Kalıcı (retry anlamsız) mantık hataları — açıkça fatal kısa-devre.
    private static readonly HashSet<int> Fatal = new()
    {
        102, 105, 156,   // syntax / unclosed quote / keyword
        207, 208,        // geçersiz kolon / nesne (tablo yok)
        229, 230, 297,   // izin reddedildi
        18456, 18452, 18470,  // login failed / not associated / disabled (yanlış kimlik — retry anlamsız)
        2812,            // saklı yordam bulunamadı
        8134,            // sıfıra bölme
        245, 8114, 8115, // dönüşüm / overflow
    };

    /// <summary>Exception cause zincirini yürüyüp transient mi fatal mı belirler.</summary>
    public static SqlErrorKind Classify(Exception ex)
    {
        for (var e = ex; e is not null; e = e.InnerException)
        {
            if (e is SqlException sql)
            {
                foreach (SqlError err in sql.Errors)
                {
                    if (Transient.Contains(err.Number)) return SqlErrorKind.Transient;
                    if (Fatal.Contains(err.Number)) return SqlErrorKind.Fatal;
                }
                if (Transient.Contains(sql.Number)) return SqlErrorKind.Transient;
                if (Fatal.Contains(sql.Number)) return SqlErrorKind.Fatal;
                // Bilinmeyen SQL hata → retry-safe (max-2 ile sınırlı; plan-12 WS-5 "bilinmeyen=transient").
                return SqlErrorKind.Transient;
            }
            if (e is TimeoutException) return SqlErrorKind.Transient;
            if (e is System.Net.Sockets.SocketException) return SqlErrorKind.Transient;
        }
        // Hiç SqlException/transport değil → bilinmeyen, retry-safe (bounded).
        return SqlErrorKind.Transient;
    }

    public static bool ShouldRetry(Exception ex) => Classify(ex) == SqlErrorKind.Transient;
}
