import http.server
import socketserver
import json
import urllib.parse
import os
import sys

PORT = 8080
DIRECTORY = os.path.join(os.path.dirname(__file__), "public")

DATA = {
    "summary": {
        "gross_total": 105822956.40,
        "net_total": 92348512.10,
        "receipt_count": 153376,
        "avg_basket": 690.0,
        "product_count": 526840,
        "season_period": "01.08.2026 - 30.09.2026",
        "last_updated": "11.10.2026 01:15"
    },
    "stores": [
        {
            "id": "FSM",
            "name": "FSM Mağazası",
            "code": "M01",
            "gross": 51240180.20,
            "net": 44810200.00,
            "receipts": 71420,
            "basket": 717.45,
            "items_per_basket": 3.65,
            "growth": 14.2,
            "margin": 44.8,
            "highlights": "Kitap ve Kafe çekim gücü en yüksek şube. Sepet büyüklüğü lideri."
        },
        {
            "id": "OZLUCE",
            "name": "Özlüce Mağazası",
            "code": "M02",
            "gross": 38115420.70,
            "net": 33190450.50,
            "receipts": 58310,
            "basket": 653.67,
            "items_per_basket": 3.25,
            "growth": 9.8,
            "margin": 43.2,
            "highlights": "Kırtasiye ve Çanta satışlarında en yüksek hacim. Aile profili yoğun."
        },
        {
            "id": "IST_YOLU",
            "name": "İstanbul Yolu",
            "code": "M03",
            "gross": 16467355.50,
            "net": 14347861.60,
            "receipts": 23646,
            "basket": 696.41,
            "items_per_basket": 3.82,
            "growth": -4.5,
            "margin": 39.5,
            "highlights": "Lojistik/Depo çıkışları ve kurumsal toptan işlemler sepeti büyütüyor fakat perakende trafiği sınırlı."
        }
    ],
    "categories": [
        {"name": "Kırtasiye & Okul Gereçleri", "share": 52.5, "revenue": 55557052.11, "margin": 46.2, "trend": "+18.4%"},
        {"name": "Kitap (Kültür, Sınav, Ders)", "share": 33.4, "revenue": 35344867.44, "margin": 38.5, "trend": "+5.2%"},
        {"name": "Oyuncak & Hobi", "share": 8.2, "revenue": 8677482.42, "margin": 48.0, "trend": "+22.1%"},
        {"name": "Çanta & Beslenme", "share": 8.0, "revenue": 8440000.00, "margin": 53.5, "trend": "+31.0%"},
        {"name": "Kafe & Diğer", "share": 5.9, "revenue": 6243554.43, "margin": 62.0, "trend": "+12.8%"}
    ],
    "bag_campaign": {
        "gross_sales": 8440000.0,
        "total_units": 10550,
        "discount_applied": 4220000.0,
        "actual_cost_fatAyr": 3924600.0,
        "gross_profit": 4515400.0,
        "profit_margin": 53.5,
        "commentary": "Vitrinlerdeki %50 indirime rağmen, toptan giriş maliyetlerinin (fatAyr) avantajı sayesinde %53.5 net brüt marj ve 4.52M ₺ nakit katkı sağlandı."
    },
    "maarif_risk": {
        "obsolete_units": 15661,
        "tied_capital": 3445420.0,
        "affected_grades": "1. ve 5. Sınıflar (Müfredat Değişimi)",
        "action": "Kalan müfredat dışı stoklar için acil iade ve damping/bundle konsolidasyonu."
    },
    "night_shopping": {
        "peak_hours": "20:00 - 23:00",
        "night_revenue_share": 31.4,
        "weekend_basket": 842.0,
        "weekday_basket": 615.0,
        "bundle_basket_3al2ode": 2297.0
    }
}

class CustomHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DIRECTORY, **kwargs)

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        if parsed.path == "/api/data":
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            self.wfile.write(json.dumps(DATA, ensure_ascii=False).encode("utf-8"))
        elif parsed.path == "/api/simulate":
            query = urllib.parse.parse_qs(parsed.query)
            bag_discount = float(query.get("bag_discount", [50])[0])
            bundle_boost = float(query.get("bundle_boost", [0])[0])
            
            # What-if Calculation
            base_bag_rev = 8440000.0
            base_cost = 3924600.0
            
            # Dynamic simulation response
            sim_rev = (105822956.40 - base_bag_rev) + (base_bag_rev * (100 - bag_discount) / 50.0) * (1 + bundle_boost / 100.0)
            sim_profit = (sim_rev * 0.44)
            
            resp = {
                "input_bag_discount": bag_discount,
                "input_bundle_boost": bundle_boost,
                "simulated_revenue": round(sim_rev, 2),
                "simulated_gross_profit": round(sim_profit, 2),
                "revenue_delta": round(sim_rev - 105822956.40, 2),
                "margin_estimate": round((sim_profit / sim_rev) * 100, 1)
            }
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            self.wfile.write(json.dumps(resp, ensure_ascii=False).encode("utf-8"))
        else:
            super().do_GET()

def run():
    print(f"BKM Executive Cockpit Web Server baslatiliyor...")
    print(f"Erisim: http://localhost:{PORT}")
    with socketserver.TCPServer(("", PORT), CustomHandler) as httpd:
        httpd.serve_forever()

if __name__ == "__main__":
    run()
