// Chart.js interop — Blazor'dan canvas grafikleri çizer. Dönem değişince destroy+recreate.
// Corporate tema — DaisyUI primary'den oku (yoksa indigo fallback). Kırmızı bırakıldı.
const KP = (getComputedStyle(document.documentElement).getPropertyValue('--p').trim()
  ? `oklch(${getComputedStyle(document.documentElement).getPropertyValue('--p').trim()})`
  : '#4063e6');
const KP_FILL = 'rgba(64,99,230,.12)';
const PAL = [KP, '#0ea5e9', '#22c55e', '#f59e0b', '#a855f7', '#64748b', '#ec4899', '#14b8a6'];
const store = {};

// Datalabels plugin global kayıt (donut %, bar değer). Yoksa sessiz geç.
if (window.Chart && window.ChartDataLabels) Chart.register(window.ChartDataLabels);

function fmtM(v) { return (v / 1e6).toFixed(1) + 'M'; }
function fmtK(v) { return v >= 1e6 ? fmtM(v) : v >= 1000 ? (v / 1000).toFixed(1) + 'B' : v; }

function draw(id, cfg) {
    const el = document.getElementById(id);
    if (!el) return;
    if (store[id]) store[id].destroy();
    store[id] = new Chart(el, cfg);
}

export function bar(id, labels, data, horizontal) {
    draw(id, {
        type: 'bar',
        data: { labels, datasets: [{ data, backgroundColor: KP }] },
        options: {
            indexAxis: horizontal ? 'y' : 'x', responsive: true, maintainAspectRatio: false,
            layout: { padding: { right: horizontal ? 38 : 0, top: horizontal ? 0 : 18 } },
            plugins: {
                legend: { display: false },
                datalabels: {
                    anchor: 'end', align: 'end', color: '#475569', font: { size: 10, weight: 600 },
                    formatter: v => fmtK(v)
                },
                tooltip: { callbacks: { label: c => ` ${c.label}: ${(c.parsed.x ?? c.parsed.y ?? c.parsed).toLocaleString('tr-TR')}` } }
            },
            scales: { [horizontal ? 'x' : 'y']: { ticks: { callback: v => v >= 1e6 ? fmtM(v) : v } } }
        }
    });
}

export function donut(id, labels, data) {
    const tot = Array.from(data).reduce((a, b) => a + b, 0);
    draw(id, {
        type: 'doughnut',
        data: { labels, datasets: [{ data, backgroundColor: PAL }] },
        options: {
            responsive: true, maintainAspectRatio: false,
            plugins: {
                legend: { position: 'right' },
                datalabels: {
                    color: '#fff', font: { size: 11, weight: 700 },
                    formatter: v => tot > 0 && v / tot >= 0.04 ? '%' + Math.round(100 * v / tot) : '',
                    textStrokeColor: 'rgba(0,0,0,.35)', textStrokeWidth: 3
                },
                tooltip: { callbacks: { label: c => ` ${c.label}: ${fmtK(c.parsed)} (%${tot > 0 ? (100 * c.parsed / tot).toFixed(1) : 0})` } }
            }
        }
    });
}

export function area(id, labels, data) {
    draw(id, {
        type: 'line',
        data: { labels, datasets: [{ data, borderColor: KP, backgroundColor: KP_FILL, fill: true, tension: .3 }] },
        options: {
            responsive: true, maintainAspectRatio: false,
            plugins: {
                legend: { display: false },
                datalabels: { align: 'top', color: '#475569', font: { size: 10, weight: 600 }, formatter: v => v }
            },
            scales: { y: { ticks: { callback: v => v >= 1e6 ? fmtM(v) : v } } }
        }
    });
}

export function scatter(id, labels, x, y) {
    const lab = Array.from(labels), xs = Array.from(x), ys = Array.from(y);
    const pts = xs.map((v, i) => ({ x: v, y: ys[i], k: lab[i] }));
    draw(id, {
        type: 'scatter',
        data: { datasets: [{ data: pts, backgroundColor: KP, pointRadius: 5, pointHoverRadius: 7 }] },
        options: {
            responsive: true, maintainAspectRatio: false,
            plugins: {
                legend: { display: false }, datalabels: { display: false },
                tooltip: { callbacks: { label: c => `${c.raw.k}: ciro ${fmtM(c.raw.x)} · stok ${fmtM(c.raw.y)}` } }
            },
            scales: {
                x: { title: { display: true, text: 'Aylık ciro' }, ticks: { callback: v => v >= 1e6 ? fmtM(v) : v } },
                y: { title: { display: true, text: 'Stok değeri' }, ticks: { callback: v => v >= 1e6 ? fmtM(v) : v } }
            }
        }
    });
}

export function barDual(id, labels, fis, net) {
    draw(id, {
        type: 'bar',
        data: { labels, datasets: [
            { label: 'Fiş', data: fis, backgroundColor: KP, yAxisID: 'y' },
            { label: 'Net ₺', data: net, type: 'line', borderColor: '#0ea5e9', yAxisID: 'y1', tension: .3 }
        ]},
        options: {
            responsive: true, maintainAspectRatio: false,
            plugins: { datalabels: { display: false } },
            scales: { y: { position: 'left' }, y1: { position: 'right', grid: { drawOnChartArea: false }, ticks: { callback: v => v >= 1e6 ? fmtM(v) : v } } }
        }
    });
}
