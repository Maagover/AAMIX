// AAMIX v1.1 portable Windows entry point.
// Compile with build_windows_launcher.ps1. No shell or PATH lookup is used.
using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Windows.Forms;

[assembly: AssemblyTitle("AAMIX")]
[assembly: AssemblyDescription("AAMIX v1.1")]
[assembly: AssemblyCompany("AAMIX")]
[assembly: AssemblyProduct("AAMIX")]
[assembly: AssemblyCopyright("AAMIX")]
[assembly: AssemblyVersion("1.1.0.0")]
[assembly: AssemblyFileVersion("1.1.0.0")]

public static class AamixLauncher
{
    public static string QuoteWindowsArgument(string argument)
    {
        // Windows CommandLineToArgvW escaping, including trailing slashes.
        var quoted = new System.Text.StringBuilder("\"");
        int slashes = 0;
        foreach (char character in argument)
        {
            if (character == '\\') { slashes++; continue; }
            if (character == '"')
            {
                quoted.Append('\\', slashes * 2 + 1).Append('"');
                slashes = 0;
                continue;
            }
            quoted.Append('\\', slashes).Append(character);
            slashes = 0;
        }
        return quoted.Append('\\', slashes * 2).Append('"').ToString();
    }

    public static ProcessStartInfo PrepareStart(string directory)
    {
        string root = Path.GetFullPath(directory);
        string engine = Path.Combine(root, "motor", "AAMIX.exe");
        string project = Path.Combine(root, "proyecto");
        if (!File.Exists(engine) || !File.Exists(Path.Combine(project, "project.godot")))
        {
            throw new FileNotFoundException(
                "Faltan archivos del juego. Extrae todo el ZIP en una carpeta y abre AAMIX.exe desde esa carpeta.");
        }
        return new ProcessStartInfo
        {
            FileName = engine,
            Arguments = "--path " + QuoteWindowsArgument(project) + " --rendering-method gl_compatibility",
            WorkingDirectory = root,
            UseShellExecute = false,
            CreateNoWindow = true
        };
    }

    [STAThread]
    public static int Main()
    {
        try
        {
            string root = Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location);
            using (Process game = Process.Start(PrepareStart(root)))
            {
                if (game == null) throw new InvalidOperationException("No se pudo abrir AAMIX.");
                game.WaitForExit();
                return game.ExitCode;
            }
        }
        catch (Exception problem)
        {
            MessageBox.Show(
                problem is FileNotFoundException ? problem.Message :
                "No se pudo abrir AAMIX. Extrae el juego completo y vuelve a intentarlo.\n\n" + problem.Message,
                "AAMIX", MessageBoxButtons.OK, MessageBoxIcon.Information);
            return 1;
        }
    }
}
