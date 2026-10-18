using System.Reflection;
using Microsoft.Win32;

namespace Percolate;

/// <summary>The tray icon, click handling and menu.</summary>
sealed class TrayApp : ApplicationContext
{
    readonly NotifyIcon tray = new();
    readonly ContextMenuStrip menu = new();
    readonly AwakeController awake = AwakeController.Shared;
    readonly System.Windows.Forms.Timer countdown = new() { Interval = 1000 };
    readonly HotKey hotKey;
    readonly Dictionary<string, Icon> icons = [];

    public TrayApp()
    {
        menu.Opening += (_, _) => BuildMenu();
        menu.Opened += (_, _) => countdown.Start();
        menu.Closed += (_, _) => countdown.Stop();
        countdown.Tick += (_, _) => { if (menu.Items.Count > 0) menu.Items[0].Text = StatusLine; };

        tray.ContextMenuStrip = menu;
        tray.MouseClick += (_, e) => { if (e.Button == MouseButtons.Left) awake.Toggle(); };
        tray.Visible = true;
        Notifier.Icon = tray;

        awake.Changed += Refresh;
        SystemEvents.UserPreferenceChanged += (_, e) =>
        {
            if (e.Category is UserPreferenceCategory.General or UserPreferenceCategory.Color) Refresh();
        };
        PowerMonitor.Shared.Start();

        hotKey = new HotKey(awake.Toggle);
        if (Settings.Current.HotKeyEnabled && !hotKey.Apply(true))
            Notifier.Show($"{HotKey.Display} is already used by another app, so Percolate's shortcut is off.");

        Refresh();
        if (Settings.Current.ActivateAtLaunch) awake.Activate(reason: null);
        // Deferred so the dialog runs inside the message loop rather than before it starts.
        if (Settings.Current.ShowWelcomeAtLaunch) SynchronizationContext.Current?.Post(_ => ShowWelcome(), null);
    }

    // Icon

    void Refresh()
    {
        string theme = TaskbarIsLight() ? "light" : "dark";
        tray.Icon = LoadIcon($"tray-{(awake.IsActive ? "on" : "off")}-{theme}.ico");
        tray.Text = StatusLine;
    }

    string StatusLine =>
        !awake.IsActive ? "Percolate is off"
        : awake.EndDate is { } end ? $"Active until {DurationFormat.Until(end)}"
        : "Active indefinitely";

    Icon LoadIcon(string name)
    {
        if (icons.TryGetValue(name, out var cached)) return cached;
        using var stream = Assembly.GetExecutingAssembly().GetManifestResourceStream(name)
                           ?? throw new InvalidOperationException($"Missing resource {name}");
        return icons[name] = new Icon(stream, SystemInformation.SmallIconSize);
    }

    static bool TaskbarIsLight()
    {
        using var key = Registry.CurrentUser.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Themes\Personalize");
        return key?.GetValue("SystemUsesLightTheme") is int v && v == 1;
    }

    // Menu

    void BuildMenu()
    {
        var s = Settings.Current;
        menu.Items.Clear();
        menu.Items.Add(new ToolStripMenuItem(StatusLine) { Enabled = false });
        menu.Items.Add(awake.IsActive ? "Deactivate" : "Activate", null, (_, _) => awake.Toggle());
        menu.Items.Add(new ToolStripSeparator());

        menu.Items.Add(new ToolStripMenuItem("Duration") { Enabled = false });
        foreach (int minutes in Settings.PresetMinutes)
        {
            menu.Items.Add(new ToolStripMenuItem("    " + DurationFormat.Label(minutes), null, (_, _) =>
            {
                s.SelectedMinutes = minutes;
                s.Save();
                awake.Activate(minutes);
            }) { Checked = minutes == s.SelectedMinutes });
        }
        menu.Items.Add(new ToolStripSeparator());

        var settings = new ToolStripMenuItem("Settings");
        settings.DropDownItems.Add(Toggle("Launch at Startup", LoginItem.IsEnabled, LoginItem.Set));
        settings.DropDownItems.Add(Toggle("Activate at Launch", s.ActivateAtLaunch, v => s.ActivateAtLaunch = v));
        settings.DropDownItems.Add(Toggle("Allow Display Sleep", s.AllowDisplaySleep, v =>
        {
            s.AllowDisplaySleep = v;
            awake.RefreshExecutionState();
        }));
        settings.DropDownItems.Add(Toggle($"Keyboard Shortcut ({HotKey.Display})", s.HotKeyEnabled, v =>
        {
            if (!hotKey.Apply(v))
            {
                Notifier.Show($"{HotKey.Display} is already used by another app.");
                v = false;
            }
            s.HotKeyEnabled = v;
        }));
        settings.DropDownItems.Add(Toggle("Allow Notifications", s.AllowNotifications, v => s.AllowNotifications = v));
        if (PowerMonitor.Shared.HasBattery)
        {
            settings.DropDownItems.Add(new ToolStripSeparator());
            settings.DropDownItems.Add(new ToolStripMenuItem("Battery") { Enabled = false });
            settings.DropDownItems.Add(Toggle("Activate on Power Connect", s.ActivateOnPowerConnect, v => s.ActivateOnPowerConnect = v));
            settings.DropDownItems.Add(Toggle("Deactivate on Power Disconnect", s.DeactivateOnPowerDisconnect, v => s.DeactivateOnPowerDisconnect = v));
            settings.DropDownItems.Add(Toggle($"Deactivate When Below {Settings.LowBatteryThreshold}%", s.DeactivateOnLowBattery, v => s.DeactivateOnLowBattery = v));
        }
        menu.Items.Add(settings);
        menu.Items.Add("About Percolate", null, (_, _) => ShowAbout());
        menu.Items.Add(new ToolStripSeparator());
        menu.Items.Add("Quit Percolate", null, (_, _) => ExitThread());
    }

    static ToolStripMenuItem Toggle(string title, bool value, Action<bool> set) =>
        new(title, null, (_, _) =>
        {
            set(!value);
            Settings.Current.Save();
        }) { Checked = value };

    // Dialogs

    static void ShowWelcome()
    {
        var showAgain = new TaskDialogVerificationCheckBox("Show this at launch", true);
        TaskDialog.ShowDialog(new TaskDialogPage
        {
            Caption = "Welcome to Percolate",
            Heading = "Percolate keeps your PC awake",
            Text = "Find the coffee cup in your system tray. Click it to toggle, right-click for durations and settings.\n\n"
                 + "Windows hides new tray icons behind the ^ arrow. To keep the cup visible, open Settings → "
                 + "Personalization → Taskbar → Other system tray icons and turn Percolate on.",
            Verification = showAgain,
            Buttons = { TaskDialogButton.OK },
        });
        Settings.Current.ShowWelcomeAtLaunch = showAgain.Checked;
        Settings.Current.Save();
    }

    static void ShowAbout()
    {
        string version = Assembly.GetExecutingAssembly().GetName().Version?.ToString(3) ?? "?";
        TaskDialog.ShowDialog(new TaskDialogPage
        {
            Caption = "About Percolate",
            Heading = $"Percolate {version}",
            Text = "A free, open-source app that keeps your PC awake.\nMIT License",
            Footnote = new TaskDialogFootnote("github.com/srujyama/percolate"),
            Buttons = { TaskDialogButton.OK },
        });
    }

    protected override void ExitThreadCore()
    {
        awake.Deactivate(reason: null);
        hotKey.Dispose();
        tray.Visible = false;
        tray.Dispose();
        base.ExitThreadCore();
    }
}
