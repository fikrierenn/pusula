// diskscan — compact native disk usage scanner (WizTree-style speed, no admin).
// FindFirstFileExW + FindExInfoBasic + LARGE_FETCH, iteratif paralel worker-pool.
// Recursion YOK (stack overflow imkansiz). Boyut WIN32_FIND_DATA'dan gelir (ekstra stat yok).
// Reparse point (junction/symlink) atlanir -> dongu + cift sayim onlenir.
//
// Kullanim:  diskscan <yol> [topN] [derinlik]
//   diskscan D:\            -> top 30, derinlik 2
//   diskscan C:\ 40 3       -> top 40, derinlik 3
//   diskscan D:\Dev 25 1    -> D:\Dev alt klasorleri

using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Threading;

internal static unsafe class Program
{
    const int MAX_PATH = 260;
    const uint FILE_ATTRIBUTE_DIRECTORY = 0x10;
    const uint FILE_ATTRIBUTE_REPARSE_POINT = 0x400;
    const int FindExInfoBasic = 1;
    const int FindExSearchNameMatch = 0;
    const int FIND_FIRST_EX_LARGE_FETCH = 2;
    static readonly IntPtr INVALID = new IntPtr(-1);

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode, Pack = 4)]
    struct WIN32_FIND_DATAW
    {
        public uint dwFileAttributes;
        public long ftCreationTime;
        public long ftLastAccessTime;
        public long ftLastWriteTime;
        public uint nFileSizeHigh;
        public uint nFileSizeLow;
        public uint dwReserved0;
        public uint dwReserved1;
        public fixed char cFileName[MAX_PATH];
        public fixed char cAlternateFileName[14];
    }

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    static extern IntPtr FindFirstFileExW(string lpFileName, int infoLevel,
        out WIN32_FIND_DATAW data, int searchOp, IntPtr filter, int flags);

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    static extern bool FindNextFileW(IntPtr h, out WIN32_FIND_DATAW data);

    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool FindClose(IntPtr h);

    static readonly ConcurrentDictionary<string, long> Records = new(StringComparer.OrdinalIgnoreCase);
    static readonly ConcurrentQueue<string> Queue = new();
    static long pending = 0;
    static long totalBytes = 0;
    static long fileCount = 0;
    static long dirCount = 0;

    static string rootNoSlash;   // "D:" veya "D:\Dev"
    static int relStart;          // goreli yol baslangic index'i (rootNoSlash.Length + 1)
    static int maxDepth;

    static int Main(string[] args)
    {
        string root = args.Length > 0 ? args[0] : System.IO.Directory.GetCurrentDirectory();
        int topN = args.Length > 1 && int.TryParse(args[1], out var t) ? t : 30;
        maxDepth = args.Length > 2 && int.TryParse(args[2], out var d) ? d : 2;

        root = root.TrimEnd('\\', '/');
        rootNoSlash = root;                 // ornek "D:" veya "D:\Dev"
        relStart = rootNoSlash.Length + 1;  // ilk '\' sonrasi

        string firstDir = root.Length == 2 && root[1] == ':' ? root + "\\" : root;

        Console.Error.WriteLine($"Tarama: {firstDir}  (topN={topN}, derinlik={maxDepth})");
        var sw = Stopwatch.StartNew();

        Queue.Enqueue(firstDir);
        Interlocked.Increment(ref pending);

        int workers = Math.Max(4, Environment.ProcessorCount);
        var threads = new Thread[workers];
        for (int i = 0; i < workers; i++)
        {
            threads[i] = new Thread(Worker, 8 * 1024 * 1024) { IsBackground = true };
            threads[i].Start();
        }
        foreach (var th in threads) th.Join();

        sw.Stop();

        var list = new List<KeyValuePair<string, long>>(Records);
        list.Sort((a, b) => b.Value.CompareTo(a.Value));

        Console.WriteLine();
        Console.WriteLine($"{"GB",10}  Klasor");
        Console.WriteLine(new string('-', 50));
        int n = 0;
        foreach (var kv in list)
        {
            if (n++ >= topN) break;
            Console.WriteLine($"{kv.Value / 1073741824.0,10:N2}  {kv.Key}");
        }
        Console.WriteLine(new string('-', 50));
        Console.WriteLine($"{Interlocked.Read(ref totalBytes) / 1073741824.0,10:N2}  TOPLAM  ({firstDir})");
        Console.Error.WriteLine(
            $"Dosya: {Interlocked.Read(ref fileCount):N0}  Klasor: {Interlocked.Read(ref dirCount):N0}  Thread: {workers}  Sure: {sw.Elapsed.TotalSeconds:N1} sn");
        return 0;
    }

    static void Worker()
    {
        var spin = new SpinWait();
        while (true)
        {
            if (Queue.TryDequeue(out var dir))
            {
                spin.Reset();
                try { Process(dir); }
                finally { Interlocked.Decrement(ref pending); }
            }
            else
            {
                if (Interlocked.Read(ref pending) == 0) return; // tum is bitti
                spin.SpinOnce();
            }
        }
    }

    static void Process(string path)
    {
        long localFiles = 0;

        string search = path;
        if (!search.EndsWith("\\")) search += "\\";
        search = @"\\?\" + search + "*";

        WIN32_FIND_DATAW fd;
        IntPtr h = FindFirstFileExW(search, FindExInfoBasic, out fd,
            FindExSearchNameMatch, IntPtr.Zero, FIND_FIRST_EX_LARGE_FETCH);
        if (h == INVALID) return;

        long localCount = 0;
        bool withSlash = path.EndsWith("\\");
        try
        {
            do
            {
                uint attr = fd.dwFileAttributes;
                if ((attr & FILE_ATTRIBUTE_REPARSE_POINT) != 0) continue;

                if ((attr & FILE_ATTRIBUTE_DIRECTORY) != 0)
                {
                    // sadece klasorde isim gerekir (alt-yol kur). "." ".." atla.
                    if (fd.cFileName[0] == '.')
                    {
                        char c1 = fd.cFileName[1];
                        if (c1 == '\0') continue;                 // "."
                        if (c1 == '.' && fd.cFileName[2] == '\0') continue; // ".."
                    }
                    string name = new string(fd.cFileName);
                    Queue.Enqueue(withSlash ? path + name : path + "\\" + name);
                    Interlocked.Increment(ref pending);
                }
                else
                {
                    // dosyada isim ALLOC ETME -> hot path
                    localFiles += ((long)fd.nFileSizeHigh << 32) | fd.nFileSizeLow;
                    localCount++;
                }
            } while (FindNextFileW(h, out fd));
        }
        finally { FindClose(h); }

        Interlocked.Increment(ref dirCount);
        if (localCount > 0) Interlocked.Add(ref fileCount, localCount);
        if (localFiles > 0) Attribute(path, localFiles);
    }

    // Bu dizinin direkt dosya bytelarini, derinlik 1..maxDepth ata-klasorlerine ekler.
    static void Attribute(string dirPath, long size)
    {
        Interlocked.Add(ref totalBytes, size);

        // dirPath, rootNoSlash altinda mi? Goreli segmentleri gez.
        int len = dirPath.Length;
        if (len <= rootNoSlash.Length) return;           // kok dizindeki dosyalar -> sadece TOPLAM
        if (relStart > len) return;

        int depth = 0;
        int i = relStart;
        while (i <= len && depth < maxDepth)
        {
            // bir sonraki '\' (veya yol sonu)
            int sep = dirPath.IndexOf('\\', i);
            int end = sep < 0 ? len : sep;
            depth++;
            string prefix = dirPath.Substring(0, end);   // root + ilk 'depth' segment
            Records.AddOrUpdate(prefix, size, (k, old) => old + size);
            if (sep < 0) break;
            i = sep + 1;
        }
    }
}
