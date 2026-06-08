USE DerinSISBkm;
GO

-- =============================================================
-- bkm.IskontoTanimYuzdeElliKampanya
-- %50 Indirim kampanyasına özel yayınevi geri dönüş iskonto tanımı.
-- Üç tip kayıt: Marka (mrkID), Barkod (BarkodAna), Verilmeyen (BarkodAna)
-- Öncelik: Verilmeyen > Barkod > Marka (view'da uygulanır)
-- =============================================================

IF OBJECT_ID('bkm.IskontoTanimYuzdeElliKampanya', 'U') IS NOT NULL
    DROP TABLE bkm.IskontoTanimYuzdeElliKampanya;
GO

CREATE TABLE bkm.IskontoTanimYuzdeElliKampanya (
    Id           INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_IskontoTanimYuzdeElliKampanya PRIMARY KEY,
    Tip          VARCHAR(20)       NOT NULL,                 -- 'Marka' | 'Barkod' | 'Verilmeyen'
    Anahtar      NVARCHAR(20)      NOT NULL,                 -- mrkID (string) veya BarkodAna
    Oran         TINYINT           NULL,                     -- Yüzde (3, 5, 7, 8, 10). Verilmeyen için NULL.
    Aciklama     NVARCHAR(100)     NULL,
    EklenmeTarih DATETIME          NOT NULL
        CONSTRAINT DF_IskontoTanimYuzdeElliKampanya_EklenmeTarih DEFAULT (GETDATE()),

    CONSTRAINT UQ_IskontoTanimYuzdeElliKampanya_TipAnahtar UNIQUE (Tip, Anahtar),
    CONSTRAINT CK_IskontoTanimYuzdeElliKampanya_Tip CHECK (Tip IN ('Marka','Barkod','Verilmeyen'))
);
GO

-- Lookup indexi — view'daki üç LEFT JOIN bunu kullanır
CREATE INDEX IX_IskontoTanimYuzdeElliKampanya_Anahtar
    ON bkm.IskontoTanimYuzdeElliKampanya(Anahtar)
    INCLUDE (Tip, Oran);
GO

-- =============================================================
-- INSERT ŞABLONLARI (CSV → SQL dönüşümü)
-- =============================================================
-- marka.csv:        159;10           →  ('Marka','159',10)
-- barkod.csv:       9789...;10       →  ('Barkod','9789...',10)
-- verilmeyen.csv:   9789...          →  ('Verilmeyen','9789...',NULL)
-- =============================================================
