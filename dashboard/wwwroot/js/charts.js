// Chart.js interop — Blazor'dan canvas grafikleri çizer. Dönem değişince destroy+recreate.
// Tema renkleri DaisyUI token'larından okunur (renk-standardi: kendi palet sabiti yok). Fallback = eski hardcode.
const dv = n => { const v = getComputedStyle(document.documentElement).getPropertyValue(n).trim(); return v ? `oklch(${v})` : null; };
const KP = dv('--p') || '#4063e6';
const KP_FILL = `color-mix(in srgb, ${KP} 12%, transparent)`;
const PAL = [KP, dv('--in') || '#0ea5e9', dv('--su') || '#22c55e', dv('--wa') || '#f59e0b',
             dv('--s') || '#a855f7', dv('--a') || '#64748b', dv('--er') || '#ec4899', dv('--n') || '#14b8a6'];
const store = {};

// Datalabels plugin global kayıt (donut %, bar değer). Yoksa sessiz geç.
if (window.Chart && window.ChartDataLabels) Chart.register(window.ChartDataLabels);

function fmtM(v) { return (v / 1e6).toFixed(1) + 'M'; }
// Datalabel: milyon+ kısalt (1,2M), altı binlik ayraçlı tam (4.193). 'B'/'bin' karışıklığı yok.
function fmtK(v) { return Math.abs(v) >= 1e6 ? fmtM(v) : Number(v).toLocaleString('tr-TR'); }

function draw(id, cfg) {
    const el = document.getElementById(id);
    if (!el) return;
    if (store[id]) store[id].destroy();
    store[id] = new Chart(el, cfg);
}

export function bar(id, labels, data, horizontal) {
    const arr = Array.from(data);
    const tot = arr.reduce((a, b) => a + (b > 0 ? b : 0), 0);
    const pct = v => tot > 0 ? Math.round(100 * v / tot) : 0;
    draw(id, {
        type: 'bar',
        data: { labels, datasets: [{ data, backgroundColor: KP }] },
        options: {
            indexAxis: horizontal ? 'y' : 'x', responsive: true, maintainAspectRatio: false,
            interaction: { intersect: false, mode: 'index' },   // mobil: tam bar'a basmadan tooltip
            layout: { padding: { right: horizontal ? 52 : 0, top: horizontal ? 0 : 26 } },
            plugins: {
                legend: { display: false },
                datalabels: {
                    anchor: 'end', align: 'end', color: '#475569', font: { size: horizontal ? 9 : 10, weight: 600 }, clamp: true,
                    formatter: v => fmtK(v)   // sadece değer; oran hover hint'inde
                },
                tooltip: { callbacks: { label: c => ` ${c.label}: ${Number(c.raw).toLocaleString('tr-TR')} (%${pct(c.raw)})` } }
            },
            scales: { [horizontal ? 'x' : 'y']: { ticks: { callback: v => v >= 1e6 ? fmtM(v) : v } } }
        }
    });
}

// Sezon-renkli dikey bar: labels 'YYYY-MM'; sezMonths ['08','09','10'] gibi → o aylar warning, diğerleri primary.
export function barSez(id, labels, data, sezMonths) {
    const arr = Array.from(data);
    const tot = arr.reduce((a, b) => a + (b > 0 ? b : 0), 0);
    const pct = v => tot > 0 ? Math.round(100 * v / tot) : 0;
    const SEZ = dv('--wa') || '#f59e0b';
    const sez = new Set(Array.from(sezMonths));
    const colors = Array.from(labels).map(l => sez.has(String(l).slice(5)) ? SEZ : KP);
    draw(id, {
        type: 'bar',
        data: { labels, datasets: [{ data, backgroundColor: colors }] },
        options: {
            responsive: true, maintainAspectRatio: false,
            interaction: { intersect: false, mode: 'index' },
            layout: { padding: { top: 22 } },
            plugins: {
                legend: { display: false },
                datalabels: { anchor: 'end', align: 'end', color: '#475569', font: { size: 9, weight: 600 }, clamp: true,
                    formatter: v => v > 0 ? fmtK(v) : '' },
                tooltip: { callbacks: { label: c => ` ${c.label}: ${Number(c.raw).toLocaleString('tr-TR')} (%${pct(c.raw)})${sez.has(String(c.label).slice(5)) ? ' · sezon' : ''}` } }
            },
            scales: { y: { ticks: { callback: v => v >= 1e6 ? fmtM(v) : v } } }
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
            interaction: { intersect: false, mode: 'nearest' },   // mobil: dilime yakın dokun
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

// Mobil sparkline: dikey gradient dolgu, gridsiz, yumuşak çizgi. Eksen minimal (y gizli, x seyrek).
export function area(id, labels, data) {
    const fill = (ctx) => {
        const { chartArea, ctx: c } = ctx.chart;
        if (!chartArea) return KP_FILL;
        const g = c.createLinearGradient(0, chartArea.top, 0, chartArea.bottom);
        g.addColorStop(0, `color-mix(in srgb, ${KP} 28%, transparent)`);
        g.addColorStop(1, 'transparent');
        return g;
    };
    draw(id, {
        type: 'line',
        data: { labels, datasets: [{ data, borderColor: KP, backgroundColor: fill, fill: true, tension: .4, pointRadius: 0, pointHoverRadius: 5, pointHoverBackgroundColor: KP, borderWidth: 2.5 }] },
        options: {
            responsive: true, maintainAspectRatio: false,
            interaction: { intersect: false, mode: 'index' },   // mobil: noktaya yakın dokun
            plugins: {
                legend: { display: false },
                datalabels: { display: false },
                tooltip: { displayColors: false, callbacks: { label: c => ' ' + fmtK(c.parsed.y) } }
            },
            scales: {
                x: { ticks: { maxRotation: 0, autoSkip: true, maxTicksLimit: 5, font: { size: 10 }, color: '#94a3b8' }, grid: { display: false }, border: { display: false } },
                y: { ticks: { maxTicksLimit: 4, font: { size: 10 }, color: '#94a3b8', callback: v => v >= 1e6 ? fmtM(v) : fmtK(v) }, grid: { display: false }, border: { display: false } }
            }
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

// Hero carousel dot göstergesi: scrollLeft → aktif kart index → dot opacity/genişlik.
// Idempotent: listener bir kez bağlanır (dataset guard). Framework yok, saf scroll.
export function heroDots(carouselId, dotsId) {
    const car = document.getElementById(carouselId), dots = document.getElementById(dotsId);
    if (!car || !dots) return;
    const sync = () => {
        // adım = kart genişliği + gap (ilk iki kartın offset farkı; peek'li layout'ta doğru)
        const step = car.children.length > 1 ? car.children[1].offsetLeft - car.children[0].offsetLeft : car.clientWidth;
        const idx = step > 0 ? Math.round(car.scrollLeft / step) : 0;
        [...dots.children].forEach((d, i) => d.classList.toggle('hero-dot-on', i === idx));
    };
    if (!car.dataset.dotsBound) { car.addEventListener('scroll', sync, { passive: true }); car.dataset.dotsBound = '1'; }
    sync();
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
