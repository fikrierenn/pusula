// DaisyUI semantic token → ApexCharts renk köprüsü (plan-08, renk-standardi.md).
// --p/--in/--su/--er/--wa ham oklch bileşenini (L C H) okur, oklch(...) sarar.
// Tema (data-theme) değişince grafik renkleri otomatik uyar. Fallback corporate primary.
export function daisyColors() {
    const r = getComputedStyle(document.documentElement);
    const c = (t) => { const v = r.getPropertyValue(t).trim(); return v ? `oklch(${v})` : null; };
    return {
        p: c('--p') ?? '#4063e6',
        in: c('--in') ?? '#0ea5e9',
        su: c('--su') ?? '#22c55e',
        er: c('--er') ?? '#ef4444',
        wa: c('--wa') ?? '#f59e0b',
    };
}
