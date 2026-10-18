using Microsoft.Win32;

namespace Percolate;

/// <summary>Watches power source changes and applies the battery-related triggers.</summary>
sealed class PowerMonitor
{
    public static PowerMonitor Shared { get; } = new();

    public bool IsOnAC { get; private set; } = true;
    public int? Percent { get; private set; }
    public bool HasBattery => Percent != null;

    // Not every PC reports percentage changes as power events, so also check once a minute.
    readonly System.Windows.Forms.Timer poll = new() { Interval = 60_000 };

    public void Start()
    {
        Read();
        SystemEvents.PowerModeChanged += (_, e) =>
        {
            if (e.Mode == PowerModes.StatusChange) PowerChanged();
        };
        poll.Tick += (_, _) => PowerChanged();
        poll.Start();
    }

    void Read()
    {
        var status = SystemInformation.PowerStatus;
        IsOnAC = status.PowerLineStatus != PowerLineStatus.Offline;
        bool noBattery = status.BatteryChargeStatus.HasFlag(BatteryChargeStatus.NoSystemBattery)
                         || status.BatteryChargeStatus == BatteryChargeStatus.Unknown;
        Percent = noBattery ? null : (int)Math.Round(status.BatteryLifePercent * 100);
    }

    void PowerChanged()
    {
        bool wasOnAC = IsOnAC;
        int? oldPercent = Percent;
        Read();
        var awake = AwakeController.Shared;
        var s = Settings.Current;

        if (!wasOnAC && IsOnAC)
        {
            if (s.ActivateOnPowerConnect && !awake.IsActive) awake.Activate(reason: Notifier.Event.ChargerConnected);
        }
        else if (wasOnAC && !IsOnAC)
        {
            if (s.DeactivateOnPowerDisconnect && awake.IsActive) awake.Deactivate(Notifier.Event.ChargerDisconnected);
        }

        int threshold = Settings.LowBatteryThreshold;
        if (s.DeactivateOnLowBattery && !IsOnAC && awake.IsActive && Percent is { } p && p < threshold
            && ((oldPercent ?? 100) >= threshold || wasOnAC))
        {
            awake.Deactivate(Notifier.Event.LowBattery);
        }
    }
}
