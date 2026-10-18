using System.IO.Pipes;

namespace Percolate;

static class Program
{
    static readonly string InstanceName = $"Percolate.{Environment.UserName}";

    /// <summary>
    /// Percolate.exe [--toggle | --on [minutes] | --off]
    /// With a command and Percolate already running, the command is sent to the running copy and
    /// this process exits, so scripts and Task Scheduler can drive it.
    /// </summary>
    [STAThread]
    static void Main(string[] args)
    {
        using var mutex = new Mutex(true, @"Local\" + InstanceName, out bool firstInstance);
        if (!firstInstance)
        {
            Send(args.Length > 0 ? string.Join(' ', args) : "");
            return;
        }

        ApplicationConfiguration.Initialize();
        SynchronizationContext.SetSynchronizationContext(new WindowsFormsSynchronizationContext());
        var ui = SynchronizationContext.Current!;
        var app = new TrayApp();
        StartCommandServer(ui);
        if (args.Length > 0) Run(string.Join(' ', args));
        Application.Run(app);
    }

    /// <summary>Applies one command line. Runs on the UI thread.</summary>
    static void Run(string command)
    {
        var parts = command.Split(' ', StringSplitOptions.RemoveEmptyEntries);
        if (parts.Length == 0) return;
        int? minutes = parts.Length > 1 && int.TryParse(parts[1], out int m) ? Math.Max(0, m) : null;
        var awake = AwakeController.Shared;
        switch (parts[0].TrimStart('-', '/').ToLowerInvariant())
        {
            case "toggle": awake.Toggle(); break;
            case "on" or "activate": awake.Activate(minutes); break;
            case "off" or "deactivate": awake.Deactivate(); break;
        }
    }

    static void Send(string command)
    {
        try
        {
            using var pipe = new NamedPipeClientStream(".", InstanceName, PipeDirection.Out, PipeOptions.CurrentUserOnly);
            pipe.Connect(2000);
            using var writer = new StreamWriter(pipe);
            writer.WriteLine(command);
        }
        catch (Exception e)
        {
            Log.Write($"Couldn't reach the running Percolate: {e.Message}");
        }
    }

    static void StartCommandServer(SynchronizationContext ui)
    {
        var thread = new Thread(() =>
        {
            while (true)
            {
                try
                {
                    using var pipe = new NamedPipeServerStream(InstanceName, PipeDirection.In, 1,
                        PipeTransmissionMode.Byte, PipeOptions.CurrentUserOnly);
                    pipe.WaitForConnection();
                    using var reader = new StreamReader(pipe);
                    string line = reader.ReadLine() ?? "";
                    ui.Post(_ => Run(line), null);
                }
                catch (Exception e)
                {
                    Log.Write($"Command pipe error: {e.Message}");
                    Thread.Sleep(1000);
                }
            }
        }) { IsBackground = true, Name = "Percolate command pipe" };
        thread.Start();
    }
}
