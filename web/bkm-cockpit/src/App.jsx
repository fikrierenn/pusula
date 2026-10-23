import React, { useState, useMemo } from 'react';
import { 
  Table, 
  FileSpreadsheet, 
  Download, 
  Filter, 
  ArrowUpDown, 
  ChevronDown, 
  Search, 
  TrendingUp, 
  TrendingDown, 
  CheckCircle2, 
  AlertTriangle, 
  Lightbulb, 
  Building2, 
  Layers, 
  ShoppingBag, 
  Sliders, 
  Maximize2,
  Minimize2,
  RefreshCw,
  ExternalLink
} from 'lucide-react';
import excelData from './data/excelDump.json';

export default function App() {
  // Active Sheet Tab (Just like Excel Sheets at bottom/top)
  const [activeSheet, setActiveSheet] = useState('Konsolide Yönetici Özeti');
  
  // Store filter ONLY applied when on "Şube Benchmarking" tab or when viewing store breakdowns
  const [selectedStore, setSelectedStore] = useState('ALL');
  
  // Table search & sort
  const [searchTerm, setSearchTerm] = useState('');
  const [sortCol, setSortCol] = useState(null);
  const [sortAsc, setSortAsc] = useState(true);

  // Sheets definition
  const sheets = [
    { id: 'Konsolide Yönetici Özeti', name: '📊 Konsolide Yönetici Özeti', isStoreSpecific: false },
    { id: 'Kategori Performans Matrisi', name: '📦 Kategori Performans Matrisi', isStoreSpecific: false },
    { id: 'Şube Benchmarking', name: '🏬 Şube Benchmarking', isStoreSpecific: true },
    { id: 'Çanta & Arbitraj Maliyeti', name: '🎒 Çanta & Arbitraj Maliyeti', isStoreSpecific: false },
    { id: 'Hazırlık & Maarif Analizi', name: '📚 Hazırlık & Maarif Analizi', isStoreSpecific: false },
    { id: 'Envanter & Merkez WMS', name: '🏭 Envanter & Merkez WMS', isStoreSpecific: false },
    { id: 'Gece Pazarı & Kampanyalar', name: '🌙 Gece Pazarı & Kampanyalar', isStoreSpecific: false },
    { id: 'Sınav Okulları Velisi', name: '🎓 Sınav Okulları Velisi', isStoreSpecific: false },
  ];

  const currentSheetDef = sheets.find(s => s.id === activeSheet);

  // Raw Sheet Data
  const rawSheetRows = excelData[activeSheet] || [];
  const title = rawSheetRows[0] ? rawSheetRows[0][0] : '';
  const subtitle = rawSheetRows[1] ? rawSheetRows[1][0] : '';
  
  // Table headers and body
  const headers = rawSheetRows[2] ? rawSheetRows[2].filter(h => h !== '') : [];
  const bodyRows = rawSheetRows.slice(3).filter(row => row.some(c => c !== ''));

  // Filtered rows by search and store (store filter only affects store sheet)
  const filteredRows = useMemo(() => {
    return bodyRows.filter(row => {
      // Store filter applies ONLY on "Şube Benchmarking"
      if (currentSheetDef.isStoreSpecific && selectedStore !== 'ALL') {
        const storeCell = row[0] || '';
        if (selectedStore === 'FSM' && !storeCell.includes('FSM')) return false;
        if (selectedStore === 'OZLUCE' && !storeCell.includes('Özlüce')) return false;
        if (selectedStore === 'IST_YOLU' && !storeCell.includes('İstanbul Yolu')) return false;
      }

      // General Search
      if (searchTerm) {
        return row.some(cell => String(cell).toLowerCase().includes(searchTerm.toLowerCase()));
      }
      return true;
    });
  }, [bodyRows, searchTerm, selectedStore, currentSheetDef.isStoreSpecific]);

  // Handle sort
  const handleSort = (idx) => {
    if (sortCol === idx) {
      setSortAsc(!sortAsc);
    } else {
      setSortCol(idx);
      setSortAsc(true);
    }
  };

  const sortedRows = useMemo(() => {
    if (sortCol === null) return filteredRows;
    return [...filteredRows].sort((a, b) => {
      const valA = a[sortCol] || '';
      const valB = b[sortCol] || '';
      
      // Clean numeric comparison if possible
      const cleanA = parseFloat(String(valA).replace(/[^0-9.-]+/g, ''));
      const cleanB = parseFloat(String(valB).replace(/[^0-9.-]+/g, ''));

      if (!isNaN(cleanA) && !isNaN(cleanB)) {
        return sortAsc ? cleanA - cleanB : cleanB - cleanA;
      }
      return sortAsc ? String(valA).localeCompare(String(valB), 'tr') : String(valB).localeCompare(String(valA), 'tr');
    });
  }, [filteredRows, sortCol, sortAsc]);

  return (
    <div className="flex flex-col h-screen bg-[#F8F9FA] text-[#212529] font-sans antialiased overflow-hidden select-none">
      
      {/* 1. EXCEL RIBBON TOP BAR */}
      <header className="bg-[#107C41] text-white px-4 py-2 flex items-center justify-between shadow-sm shrink-0">
        <div className="flex items-center space-x-3">
          <div className="p-1.5 bg-white/10 rounded flex items-center justify-center">
            <FileSpreadsheet className="w-5 h-5 text-white" />
          </div>
          <div>
            <div className="flex items-center space-x-2">
              <span className="font-bold text-sm tracking-wide">BKM Kitap · Excel Yönetim Modeli</span>
              <span className="text-[10px] bg-white/20 px-2 py-0.5 rounded font-mono font-medium">
                2026 Sezonu (61 Gün)
              </span>
            </div>
            <p className="text-[11px] text-white/80">
              Canlı SQL (EncoreMerkez POS & DerinSIS ERP) Entegre Çok Sayfalı Çalışma Kitabı
            </p>
          </div>
        </div>

        {/* Global Action Tools */}
        <div className="flex items-center space-x-3">
          <a
            href="/BKM-Kitap-2026-Okul-Sezonu-Detayli-Yonetim-Raporu.xlsx"
            download
            className="flex items-center space-x-1.5 px-3 py-1.5 rounded bg-white text-[#107C41] text-xs font-bold hover:bg-slate-100 transition-all shadow-sm"
          >
            <Download className="w-3.5 h-3.5" />
            <span>Orijinal .xlsx İndir</span>
          </a>
        </div>
      </header>

      {/* 2. EXCEL FORMULA & CONTEXT BAR */}
      <div className="bg-[#FFFFFF] border-b border-[#E1DFDD] px-4 py-2 flex items-center justify-between shrink-0 text-xs">
        <div className="flex items-center space-x-3 flex-1">
          <div className="font-mono bg-[#F3F2F1] px-2.5 py-1 rounded border border-[#EDEBE9] font-bold text-[#323130] text-[11px]">
            {activeSheet.toUpperCase()}
          </div>
          <div className="text-[#605E5C] text-xs truncate max-w-2xl font-medium">
            {subtitle || title}
          </div>
        </div>

        {/* Search Input */}
        <div className="flex items-center space-x-2">
          <div className="relative">
            <Search className="w-3.5 h-3.5 absolute left-2.5 top-2 text-[#605E5C]" />
            <input 
              type="text" 
              placeholder="Tabloda ara..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              className="pl-8 pr-3 py-1 rounded bg-[#F3F2F1] border border-[#EDEBE9] text-xs focus:bg-white focus:outline-none focus:ring-1 focus:ring-[#107C41] w-48 transition-all"
            />
          </div>

          {/* STORE SELECTION: VISIBLE ONLY ON STORE-SPECIFIC TABS */}
          {currentSheetDef.isStoreSpecific && (
            <div className="flex items-center space-x-1.5 bg-[#F3F2F1] p-1 rounded border border-[#EDEBE9]">
              <span className="text-[10px] font-bold text-[#605E5C] px-1 uppercase flex items-center space-x-1">
                <Building2 className="w-3 h-3 mr-0.5 text-[#107C41]" />
                <span>Şube:</span>
              </span>
              {[
                { id: 'ALL', label: 'Tüm Şubeler' },
                { id: 'FSM', label: 'FSM' },
                { id: 'OZLUCE', label: 'Özlüce' },
                { id: 'IST_YOLU', label: 'İst. Yolu' }
              ].map(s => (
                <button
                  key={s.id}
                  onClick={() => setSelectedStore(s.id)}
                  className={`px-2 py-0.5 rounded text-[11px] font-semibold transition-all ${
                    selectedStore === s.id 
                      ? 'bg-[#107C41] text-white shadow-xs' 
                      : 'text-[#605E5C] hover:bg-white hover:text-black'
                  }`}
                >
                  {s.label}
                </button>
              ))}
            </div>
          )}
        </div>
      </div>

      {/* 3. SPREADSHEET TABLE GRID CONTAINER */}
      <div className="flex-1 overflow-auto bg-white p-4">
        
        {/* Special Minto Callout if on Executive Sheet */}
        {activeSheet === 'Konsolide Yönetici Özeti' && (
          <div className="mb-6 grid grid-cols-3 gap-4">
            <div className="p-4 rounded-lg bg-[#E6F4EA] border border-[#CEEAD6] space-y-1.5">
              <div className="flex items-center space-x-1.5 text-[#137333] font-bold text-xs uppercase">
                <CheckCircle2 className="w-4 h-4" />
                <span>3 Stratejik Zafer</span>
              </div>
              <ul className="text-xs text-[#202124] space-y-1 list-disc list-inside">
                <li><strong>Kırtasiye:</strong> +137K adet hacim sıçraması (80,5M ₺ ciro).</li>
                <li><strong>Oyuncak:</strong> +%51,6 adet artışı (18,0M ₺ ciro).</li>
                <li><strong>Çanta:</strong> %50 indirimle 15,3M ₺ ciro & %59,9 net marj.</li>
              </ul>
            </div>

            <div className="p-4 rounded-lg bg-[#FCE8E6] border border-[#FAD2CF] space-y-1.5">
              <div className="flex items-center space-x-1.5 text-[#C5221F] font-bold text-xs uppercase">
                <AlertTriangle className="w-4 h-4" />
                <span>2 Kritik Alarm</span>
              </div>
              <ul className="text-xs text-[#202124] space-y-1 list-disc list-inside">
                <li><strong>Maarif Batığı:</strong> 15.661 adet kilitli eski müfredat.</li>
                <li><strong>FSM 3. Kat:</strong> Dikey sürtünmeyle çocuk kitabında -3.98M ₺ kayıp.</li>
              </ul>
            </div>

            <div className="p-4 rounded-lg bg-[#FEF7E0] border border-[#FEEFC3] space-y-1.5">
              <div className="flex items-center space-x-1.5 text-[#B06000] font-bold text-xs uppercase">
                <Lightbulb className="w-4 h-4" />
                <span>1 Büyük Fırsat</span>
              </div>
              <p className="text-xs text-[#202124] leading-relaxed">
                <strong>Sınav Lise Velisindeki %53 Kaçak:</strong> 1.450 lise velisine 2.900 ₺'lik YKS paketi satılsaydı kasaya <strong>+4,2 Milyon TL</strong> ek nakit girecekti.
              </p>
            </div>
          </div>
        )}

        {/* The Spreadsheet Grid Table */}
        <div className="border border-[#D2D0CE] rounded shadow-xs overflow-hidden bg-white">
          <table className="w-full text-left border-collapse text-xs">
            
            {/* Table Header Row */}
            <thead>
              <tr className="bg-[#F3F2F1] border-b border-[#D2D0CE]">
                <th className="py-2.5 px-3 w-12 text-center text-[#605E5C] font-mono text-[11px] border-r border-[#D2D0CE] bg-[#EDEBE9]">
                  #
                </th>
                {headers.map((h, i) => (
                  <th 
                    key={i}
                    onClick={() => handleSort(i)}
                    className="py-2.5 px-3 font-bold text-[#323130] text-xs border-r border-[#D2D0CE] cursor-pointer hover:bg-[#E1DFDD] transition-colors select-none"
                  >
                    <div className="flex items-center justify-between space-x-1">
                      <span className="truncate">{h}</span>
                      <ArrowUpDown className="w-3 h-3 text-[#A19F9D] shrink-0" />
                    </div>
                  </th>
                ))}
              </tr>
            </thead>

            {/* Table Body Rows */}
            <tbody className="divide-y divide-[#EDEBE9] font-mono">
              {sortedRows.length > 0 ? (
                sortedRows.map((row, rIdx) => {
                  const isHighlightRow = row.some(c => String(c).includes('Toplam') || String(c).includes('Konsolide'));
                  return (
                    <tr 
                      key={rIdx} 
                      className={`hover:bg-[#F3F9F4] transition-colors ${
                        isHighlightRow ? 'bg-[#F9F8F7] font-bold text-[#004B1C]' : ''
                      }`}
                    >
                      {/* Row Index */}
                      <td className="py-2 px-3 text-center text-[#A19F9D] font-mono text-[10px] border-r border-[#EDEBE9] bg-[#FAF9F8]">
                        {rIdx + 1}
                      </td>

                      {/* Columns */}
                      {headers.map((_, cIdx) => {
                        const cellVal = row[cIdx] !== undefined ? row[cIdx] : '';
                        const isPositive = String(cellVal).startsWith('+');
                        const isNegative = String(cellVal).startsWith('-');
                        const isCurrency = !isNaN(parseFloat(cellVal)) && cellVal.length > 4 && !String(cellVal).includes('%');

                        return (
                          <td 
                            key={cIdx} 
                            className={`py-2 px-3 border-r border-[#EDEBE9] truncate max-w-xs ${
                              isPositive ? 'text-[#107C41] font-semibold' : ''
                            } ${isNegative ? 'text-[#A80000] font-semibold' : ''}`}
                            title={String(cellVal)}
                          >
                            {cellVal}
                          </td>
                        );
                      })}
                    </tr>
                  );
                })
              ) : (
                <tr>
                  <td colSpan={headers.length + 1} className="py-8 text-center text-[#605E5C] text-xs">
                    Aranan kriterlere uygun satır bulunamadı.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>

        {/* Table Footer Status */}
        <div className="mt-2 flex items-center justify-between text-[11px] text-[#605E5C] px-1 font-mono">
          <span>Toplam Satır: {sortedRows.length} / {bodyRows.length}</span>
          <span>Aktif Sekme: {activeSheet}</span>
        </div>
      </div>

      {/* 4. EXCEL SHEET TABS (BOTTOM WORKBOOK SWITCHER) */}
      <footer className="bg-[#EDEBE9] border-t border-[#D2D0CE] px-3 py-1 flex items-center justify-between shrink-0">
        <div className="flex items-center space-x-1 overflow-x-auto py-0.5">
          {sheets.map((sheet) => (
            <button
              key={sheet.id}
              onClick={() => {
                setActiveSheet(sheet.id);
                setSearchTerm('');
                setSortCol(null);
              }}
              className={`px-3 py-1.5 rounded-t text-xs font-medium tracking-tight transition-all flex items-center space-x-1.5 whitespace-nowrap border-t-2 ${
                activeSheet === sheet.id
                  ? 'bg-white text-[#107C41] border-[#107C41] shadow-xs font-bold'
                  : 'bg-[#F3F2F1] text-[#605E5C] border-transparent hover:bg-white hover:text-[#323130]'
              }`}
            >
              <span>{sheet.name}</span>
            </button>
          ))}
        </div>

        <div className="text-[11px] font-mono text-[#605E5C] px-2 shrink-0">
          Excel Formüllü Analiz Modeli
        </div>
      </footer>

    </div>
  );
}
