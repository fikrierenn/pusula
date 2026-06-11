// Chart.js interop — Blazor'dan canvas grafikleri çizer. Dönem değişince destroy+recreate.
const KP = '#E30622';
const PAL = [KP, '#f59e0b', '#0ea5e9', '#64748b', '#16a34a', '#a855f7', '#ec4899', '#14b8a6'];
const store = {};

function fmtM(v) { return (v / 1e6).toFixed(1) + 'M'; }

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
            plugins: { legend: { display: false } },
            scales: { [horizontal ? 'x' : 'y']: { ticks: { callback: v => v >= 1e6 ? fmtM(v) : v } } }
        }
    });
}

export function donut(id, labels, data) {
    draw(id, {
        type: 'doughnut',
        data: { labels, datasets: [{ data, backgroundColor: PAL }] },
        options: { responsive: true, maintainAspectRatio: false, plugins: { legend: { position: 'right' } } }
    });
}

export function area(id, labels, data) {
    draw(id, {
        type: 'line',
        data: { labels, datasets: [{ data, borderColor: KP, backgroundColor: 'rgba(227,6,34,.12)', fill: true, tension: .3 }] },
        options: {
            responsive: true, maintainAspectRatio: false,
            plugins: { legend: { display: false } },
            scales: { y: { ticks: { callback: v => v >= 1e6 ? fmtM(v) : v } } }
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
            scales: { y: { position: 'left' }, y1: { position: 'right', grid: { drawOnChartArea: false }, ticks: { callback: v => v >= 1e6 ? fmtM(v) : v } } }
        }
    });
}
