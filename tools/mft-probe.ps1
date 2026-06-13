# Probe3: SeBackupPrivilege ENABLE -> $MFT dosya ac + oku
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class Probe {
  [DllImport("kernel32.dll", SetLastError=true, CharSet=CharSet.Unicode)]
  static extern IntPtr CreateFileW(string n, uint a, uint s, IntPtr sec, uint d, uint f, IntPtr t);
  [DllImport("kernel32.dll", SetLastError=true)]
  static extern bool ReadFile(IntPtr h, byte[] buf, uint n, out uint read, IntPtr ov);
  [DllImport("kernel32.dll", SetLastError=true)]
  static extern uint GetFileSize(IntPtr h, out uint hi);
  [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr h);

  [DllImport("advapi32.dll", SetLastError=true)]
  static extern bool OpenProcessToken(IntPtr proc, uint access, out IntPtr tok);
  [DllImport("kernel32.dll")] static extern IntPtr GetCurrentProcess();
  [DllImport("advapi32.dll", SetLastError=true, CharSet=CharSet.Unicode)]
  static extern bool LookupPrivilegeValueW(string sys, string name, out long luid);
  [DllImport("advapi32.dll", SetLastError=true)]
  static extern bool AdjustTokenPrivileges(IntPtr tok, bool dis, ref TP newp, uint len, IntPtr prev, IntPtr plen);
  [StructLayout(LayoutKind.Sequential)] struct TP { public uint Count; public long Luid; public uint Attr; }
  const uint GR=0x80000000, SH=7, OPEN=3, BACKUP=0x02000000;
  const uint TOKEN_ADJ=0x20, TOKEN_QUERY=0x8, SE_ENABLED=0x2;

  public static string EnablePriv(string name){
    IntPtr tok;
    if(!OpenProcessToken(GetCurrentProcess(), TOKEN_ADJ|TOKEN_QUERY, out tok)) return "OpenToken FAIL "+Marshal.GetLastWin32Error();
    long luid;
    if(!LookupPrivilegeValueW(null, name, out luid)) return "Lookup FAIL "+Marshal.GetLastWin32Error();
    TP tp = new TP(); tp.Count=1; tp.Luid=luid; tp.Attr=SE_ENABLED;
    bool ok = AdjustTokenPrivileges(tok, false, ref tp, 0, IntPtr.Zero, IntPtr.Zero);
    int err = Marshal.GetLastWin32Error();
    CloseHandle(tok);
    return name+" adjust ok="+ok+" err="+err+(err==1300?" (NOT_ALL_ASSIGNED)":"");
  }

  public static string Try(string path){
    IntPtr h = CreateFileW(path, GR, SH, IntPtr.Zero, OPEN, BACKUP, IntPtr.Zero);
    if(h==(IntPtr)(-1)) return path+" : CreateFile FAIL err "+Marshal.GetLastWin32Error();
    try {
      uint hi; uint lo = GetFileSize(h, out hi);
      long size = ((long)hi<<32)|lo;
      byte[] b = new byte[4096];
      uint got; bool ok = ReadFile(h, b, 4096, out got, IntPtr.Zero);
      int err = Marshal.GetLastWin32Error();
      string sig = ok ? System.Text.Encoding.ASCII.GetString(b,0,4) : "";
      return path+" : "+(ok?("OK size="+size+" ("+(size/1048576)+"MB) got="+got+" sig="+sig):("ReadFile FAIL err "+err));
    } finally { CloseHandle(h); }
  }
}
'@ -Language CSharp
[Probe]::EnablePriv('SeBackupPrivilege')
[Probe]::EnablePriv('SeRestorePrivilege')
[Probe]::Try('\\.\D:\$MFT')
