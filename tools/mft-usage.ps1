<#
.SYNOPSIS
  Hizli disk kullanim tarayici — NTFS $MFT'yi HAM okur (WizTree mantigi).
  Klasor klasor recurse ETMEZ; tum FILE kayitlarini tek seferde MFT'den ceker.

.DESCRIPTION
  - \\.\<harf>: volume handle acar (ADMIN gerekir).
  - Boot sektorden bytes/sector, sectors/cluster, $MFT konumunu okur.
  - $MFT record 0'in $DATA data-run'larini parse edip MFT'nin tamamini okur.
  - Her FILE record icin: $FILE_NAME (ad + parent ref) ve unnamed $DATA (gercek boyut).
  - Parent zincirinden tam yol kurar, boyutu ust klasorlere toplar.
  - En buyuk N klasoru yazar.

.PARAMETER Drive
  Surucu harfi, orn 'D'. Varsayilan: bulundugun surucu.

.PARAMETER Top
  Kac klasor listelensin. Varsayilan 30.

.PARAMETER Depth
  Yol derinligi limiti (kok=1). Varsayilan 2 (orn D:\Dev\wistiadownloader).

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tools\mft-usage.ps1 -Drive D -Top 30 -Depth 2
#>
param(
  [string]$Drive = (Get-Location).Drive.Name,
  [int]$Top = 30,
  [int]$Depth = 2
)

$ErrorActionPreference = 'Stop'
$Drive = $Drive.TrimEnd(':','\')

# --- Admin kontrol ---
$id = [Security.Principal.WindowsIdentity]::GetCurrent()
$pr = New-Object Security.Principal.WindowsPrincipal($id)
if (-not $pr.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  Write-Error "ADMIN gerekli. Ham volume (\\.\$Drive`:) okumak yonetici hakkı ister. PowerShell'i 'Yonetici olarak calistir' ile ac."
  exit 1
}

Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;

public static class Mft
{
    [DllImport("kernel32.dll", SetLastError=true, CharSet=CharSet.Unicode)]
    static extern IntPtr CreateFileW(string name, uint access, uint share, IntPtr sec,
        uint disp, uint flags, IntPtr templ);
    [DllImport("kernel32.dll", SetLastError=true)]
    static extern bool ReadFile(IntPtr h, byte[] buf, uint n, out uint read, IntPtr ov);
    [DllImport("kernel32.dll", SetLastError=true)]
    static extern bool SetFilePointerEx(IntPtr h, long dist, out long newPtr, uint method);
    [DllImport("kernel32.dll", SetLastError=true)]
    static extern bool CloseHandle(IntPtr h);

    const uint GENERIC_READ = 0x80000000;
    const uint FILE_SHARE_RW = 0x03;
    const uint OPEN_EXISTING = 3;

    public class Rec {
        public long Parent;
        public string Name;
        public bool IsDir;
        public long Size;      // unnamed $DATA gercek boyut
        public bool InUse;
        public bool HasName;
    }

    static IntPtr h;
    static int bytesPerSector, sectorsPerCluster, bytesPerCluster, bytesPerRecord;

    static void Seek(long pos){ long np; if(!SetFilePointerEx(h,pos,out np,0)) throw new IOException("seek fail @"+pos+" err "+Marshal.GetLastWin32Error()); }
    static byte[] Read(int n){ byte[] b=new byte[n]; uint got; int off=0;
        while(off<n){ if(!ReadFile(h,_tmp(b,off),(uint)(n-off),out got,IntPtr.Zero)||got==0) throw new IOException("read fail err "+Marshal.GetLastWin32Error()); off+=(int)got; }
        return b; }
    // ReadFile cannot take offset; read into temp then copy. Simpler: read full at once.
    static byte[] _tmp(byte[] dst,int off){ return dst; } // placeholder (we read full below)

    const int ALIGN = 4096; // fiziksel sektor (4Kn) hizalamasi — ham volume okumalari katı olmali

    static byte[] ReadAt(long pos, int n){
        // pos cagiranlarda zaten cluster/0 hizali; uzunlugu 4096 katina yuvarla
        int aligned = (n + (ALIGN-1)) & ~(ALIGN-1);
        Seek(pos);
        byte[] b = new byte[aligned];
        uint got; int total=0;
        while(total<aligned){
            byte[] chunk = new byte[aligned-total];
            if(!ReadFile(h, chunk, (uint)(aligned-total), out got, IntPtr.Zero) || got==0)
                throw new IOException("read fail @"+pos+" len "+aligned+" err "+Marshal.GetLastWin32Error());
            Array.Copy(chunk,0,b,total,(int)got);
            total+=(int)got;
        }
        if(aligned==n) return b;
        byte[] r=new byte[n]; Array.Copy(b,0,r,0,n); return r;
    }

    // Update Sequence Array fixup
    static void Fixup(byte[] rec){
        int usaOff = BitConverter.ToUInt16(rec,4);
        int usaCnt = BitConverter.ToUInt16(rec,6);
        ushort usn = BitConverter.ToUInt16(rec,usaOff);
        for(int i=1;i<usaCnt;i++){
            int sectorEnd = i*bytesPerSector - 2;
            if(sectorEnd+1 >= rec.Length) break;
            // last 2 bytes of each sector should equal usn; replace with USA value
            rec[sectorEnd]   = rec[usaOff + i*2];
            rec[sectorEnd+1] = rec[usaOff + i*2 + 1];
        }
    }

    // Parse data runs -> list of (startLCN, lengthClusters)
    static List<long[]> DataRuns(byte[] attr, int runOff){
        var runs = new List<long[]>();
        int p = runOff;
        long lcn = 0;
        while(p < attr.Length && attr[p] != 0){
            int hdr = attr[p++];
            int lenSize = hdr & 0x0F;
            int offSize = (hdr >> 4) & 0x0F;
            if(lenSize==0 || p+lenSize+offSize > attr.Length) break;
            long len = 0;
            for(int i=0;i<lenSize;i++) len |= (long)attr[p+i] << (8*i);
            p += lenSize;
            long off = 0;
            for(int i=0;i<offSize;i++) off |= (long)attr[p+i] << (8*i);
            // sign extend
            if(offSize>0 && (attr[p+offSize-1] & 0x80)!=0){
                for(int i=offSize;i<8;i++) off |= (long)0xFF << (8*i);
            }
            p += offSize;
            lcn += off;
            runs.Add(new long[]{ lcn, len });
        }
        return runs;
    }

    public static Dictionary<long,Rec> Scan(string drive, out long mftRecordCount){
        h = CreateFileW("\\\\.\\"+drive+":", GENERIC_READ, FILE_SHARE_RW, IntPtr.Zero, OPEN_EXISTING, 0, IntPtr.Zero);
        if(h == (IntPtr)(-1)) throw new IOException("CreateFile fail err "+Marshal.GetLastWin32Error());
        try {
            byte[] boot = ReadAt(0, 4096);
            bytesPerSector    = BitConverter.ToUInt16(boot, 0x0B);
            sectorsPerCluster = boot[0x0D];
            bytesPerCluster   = bytesPerSector * sectorsPerCluster;
            long mftCluster   = BitConverter.ToInt64(boot, 0x30);
            sbyte cpr         = (sbyte)boot[0x40];
            bytesPerRecord    = cpr >= 0 ? cpr * bytesPerCluster : (1 << (-cpr));

            // Read $MFT record 0 to get MFT's own data runs (handle fragmented MFT)
            byte[] mftRec0 = ReadAt(mftCluster * bytesPerCluster, bytesPerRecord);
            Fixup(mftRec0);
            var mftRuns = FindDataRuns(mftRec0);

            // Build a flat reader over MFT via runs
            var recs = new Dictionary<long,Rec>();
            long recordsPerCluster = bytesPerCluster / bytesPerRecord;
            long globalIndex = 0;
            mftRecordCount = 0;

            foreach(var run in mftRuns){
                long startByte = run[0] * bytesPerCluster;
                long clusters  = run[1];
                long bytesLen  = clusters * bytesPerCluster;
                // read run in chunks (e.g. 8 MB)
                long done = 0;
                int chunkSize = 8 * 1024 * 1024;
                chunkSize -= chunkSize % bytesPerRecord;
                while(done < bytesLen){
                    int toRead = (int)Math.Min(chunkSize, bytesLen - done);
                    byte[] buf = ReadAt(startByte + done, toRead);
                    for(int o=0; o+bytesPerRecord <= buf.Length; o += bytesPerRecord){
                        long idx = globalIndex++;
                        if(buf[o]!='F'||buf[o+1]!='I'||buf[o+2]!='L'||buf[o+3]!='E') continue;
                        byte[] rec = new byte[bytesPerRecord];
                        Array.Copy(buf,o,rec,0,bytesPerRecord);
                        try { Fixup(rec); } catch { continue; }
                        Rec r = ParseRecord(rec);
                        if(r != null){ recs[idx] = r; mftRecordCount++; }
                    }
                    done += toRead;
                }
            }
            return recs;
        } finally {
            CloseHandle(h);
        }
    }

    static List<long[]> FindDataRuns(byte[] rec){
        int p = BitConverter.ToUInt16(rec, 0x14);
        while(p+8 <= rec.Length){
            uint type = BitConverter.ToUInt32(rec,p);
            if(type==0xFFFFFFFF) break;
            int len = BitConverter.ToInt32(rec,p+4);
            if(len<=0) break;
            byte nonRes = rec[p+8];
            byte nameLen = rec[p+9];
            if(type==0x80 && nameLen==0 && nonRes==1){
                int runOff = BitConverter.ToUInt16(rec,p+0x20);
                return DataRuns(rec, p+runOff);
            }
            p += len;
        }
        return new List<long[]>();
    }

    static Rec ParseRecord(byte[] rec){
        ushort flags = BitConverter.ToUInt16(rec,0x16);
        bool inUse = (flags & 0x01)!=0;
        bool isDir = (flags & 0x02)!=0;
        Rec r = new Rec(){ InUse=inUse, IsDir=isDir, Size=0, HasName=false, Parent=-1 };

        int p = BitConverter.ToUInt16(rec, 0x14);
        long dataSize = 0;
        int bestNs = -1; // prefer Win32(1)/Win32+DOS(3) over DOS(2)/POSIX(0)
        while(p+8 <= rec.Length){
            uint type = BitConverter.ToUInt32(rec,p);
            if(type==0xFFFFFFFF) break;
            int len = BitConverter.ToInt32(rec,p+4);
            if(len<=0 || p+len > rec.Length) break;
            byte nonRes = rec[p+8];
            byte nameLen = rec[p+9];

            if(type==0x30){ // $FILE_NAME (resident)
                int co = BitConverter.ToUInt16(rec,p+0x14);
                int c = p+co;
                long parentRef = BitConverter.ToInt64(rec,c) & 0x0000FFFFFFFFFFFF;
                byte fnLen = rec[c+0x40];
                byte ns = rec[c+0x41];
                int rank = (ns==1||ns==3)?2:(ns==0?1:0);
                if(rank > bestNs){
                    bestNs = rank;
                    string nm = Encoding.Unicode.GetString(rec, c+0x42, fnLen*2);
                    r.Name = nm;
                    r.Parent = parentRef;
                    r.HasName = true;
                }
            }
            else if(type==0x80 && nameLen==0){ // unnamed $DATA
                if(nonRes==0){
                    int cl = BitConverter.ToInt32(rec,p+0x10); // resident content length
                    dataSize += cl;
                } else {
                    long real = BitConverter.ToInt64(rec,p+0x30); // real size
                    dataSize += real;
                }
            }
            p += len;
        }
        r.Size = dataSize;
        if(!r.HasName) return null;
        return r;
    }
}
'@ -Language CSharp

Write-Host "Tarama: $Drive`: (HAM MFT okunuyor)..." -ForegroundColor Cyan
$sw = [Diagnostics.Stopwatch]::StartNew()

$count = 0
$recs = [Mft]::Scan($Drive, [ref]$count)

$sw.Stop()
Write-Host ("MFT okundu: {0:N0} kayit, {1:N1} sn" -f $recs.Count, $sw.Elapsed.TotalSeconds) -ForegroundColor Green

# --- Yol kur + klasor toplami ---
# recs: Dictionary[long]=Rec (key = MFT record index). Parent = parent record index.
# Root klasor record index = 5.
$folderSize = @{}   # recordIndex -> toplam byte (alt agac)
$pathCache  = @{}

function Get-Path([long]$idx){
  if($pathCache.ContainsKey($idx)){ return $pathCache[$idx] }
  if($idx -eq 5){ $pathCache[$idx] = "$Drive`:"; return $pathCache[$idx] }
  if(-not $recs.ContainsKey($idx)){ return $null }
  $r = $recs[$idx]
  $pp = Get-Path ([long]$r.Parent)
  if($null -eq $pp){ return $null }
  $full = "$pp\$($r.Name)"
  $pathCache[$idx] = $full
  return $full
}

# Her dosyanin boyutunu parent zincirine ekle
foreach($kv in $recs.GetEnumerator()){
  $r = $kv.Value
  if(-not $r.InUse){ continue }
  if($r.Size -le 0){ continue }
  $cur = [long]$r.Parent
  $guard = 0
  while($cur -ge 0 -and $guard -lt 256){
    if(-not $folderSize.ContainsKey($cur)){ $folderSize[$cur] = [long]0 }
    $folderSize[$cur] += $r.Size
    if($cur -eq 5){ break }
    if(-not $recs.ContainsKey($cur)){ break }
    $cur = [long]$recs[$cur].Parent
    $guard++
  }
}

# Derinlik filtreli klasor listesi
$rows = foreach($kv in $folderSize.GetEnumerator()){
  $idx = $kv.Key
  $path = Get-Path ([long]$idx)
  if($null -eq $path){ continue }
  $d = ($path -split '\\').Count   # "D:" -> 1 parca
  if($d -gt $Depth){ continue }
  [PSCustomObject]@{ GB = [math]::Round($kv.Value/1GB,2); Depth=$d; Path=$path }
}

$rows | Sort-Object GB -Descending | Select-Object -First $Top GB, Path | Format-Table -AutoSize
Write-Host ("Toplam sure: {0:N1} sn" -f $sw.Elapsed.TotalSeconds) -ForegroundColor Cyan
