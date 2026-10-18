namespace Percolate;

/// <summary>Notifications, shown as Windows toasts through the tray icon.</summary>
static class Notifier
{
    public enum Event { Activated, Deactivated, TimerElapsed, ChargerConnected, ChargerDisconnected, LowBattery }

    /// <summary>Set by <see cref="TrayApp"/> once the tray icon exists.</summary>
    public static NotifyIcon? Icon { get; set; }

    static string Body(Event e) => e switch
    {
        Event.Activated => "Percolate has been activated",
        Event.Deactivated => "Percolate has been deactivated",
        Event.TimerElapsed => "Timer has elapsed",
        Event.ChargerConnected => "Charger connected — Percolate activated",
        Event.ChargerDisconnected => "Charger disconnected — Percolate deactivated",
        Event.LowBattery => $"Battery below {Settings.LowBatteryThreshold}% — Percolate deactivated",
        _ => "",
    };

    public static void Post(Event e)
    {
        if (!Settings.Current.AllowNotifications) return;
        Show(Body(e));
    }

    /// <summary>Shows a message regardless of the notifications setting (for errors and first-run hints).</summary>
    public static void Show(string body) => Icon?.ShowBalloonTip(5000, "Percolate", body, ToolTipIcon.None);
}
