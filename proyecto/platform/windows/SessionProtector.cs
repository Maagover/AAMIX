using System;
using System.IO;
using System.Security.Cryptography;
using System.Text;
using System.Threading;

// Tiny stdin/stdout adapter for the native Godot client. Tokens never appear in
// process arguments or temporary files. DPAPI binds the ciphertext to the current
// Windows account. Entropy stays stable across AAMIX versions.
internal static class SessionProtector
{
    private static readonly byte[] Entropy = Encoding.UTF8.GetBytes("AAMIX.Session.v1");

    private static int Main(string[] args)
    {
        var watchdog = new Thread(delegate() { Thread.Sleep(10000); Environment.Exit(3); });
        watchdog.IsBackground = true;
        watchdog.Start();
        byte[] input = null;
        byte[] output = null;
        try
        {
            if (args.Length != 1 || (args[0] != "protect" && args[0] != "unprotect"))
                throw new InvalidDataException();
            string line = Console.In.ReadLine();
            if (line == null || line.Length < 1 || line.Length > 65536)
                throw new InvalidDataException();
            input = Convert.FromBase64String(line);
            if (input.Length > 32768) throw new InvalidDataException();
            output = args[0] == "protect"
                ? ProtectedData.Protect(input, Entropy, DataProtectionScope.CurrentUser)
                : ProtectedData.Unprotect(input, Entropy, DataProtectionScope.CurrentUser);
            Console.Out.WriteLine("OK:" + Convert.ToBase64String(output));
            Console.Out.Flush();
            return 0;
        }
        catch
        {
            // Do not print exception details, input, user names or paths.
            Console.Out.WriteLine("ERR");
            Console.Out.Flush();
            return 2;
        }
        finally
        {
            if (input != null) Array.Clear(input, 0, input.Length);
            if (output != null) Array.Clear(output, 0, output.Length);
        }
    }
}
