using System.Runtime.InteropServices;

namespace Percolate;

/// <summary>Keeps the PC awake with SetThreadExecutionState, plus the optional timer.</summary>
/// <remarks>
/// The execution state belongs to the calling thread, so every call happens on the UI thread,
/// which lives as long as the app. Windows clears it automatically if the process exits.
/// You can see it with <c>powercfg /requests</c>.
/// </remarks>
sealed class AwakeController
{
    public static AwakeController Shared { get; } = new();

    public bool IsActive { get; private set; }
    public DateTime? EndDate { get; private set; }
    public event Action? Changed;

    readonly System.Windows.Forms.Timer timer = new();

    AwakeController()
    {
        timer.Tick += (_, _) => Deactivate(Notifier.Event.TimerElapsed);
    }

    /// <summary>Activate for <paramref name="minutes"/> (null = the selected duration, 0 = indefinitely).</summary>
    public void Activate(int? minutes = null, Notifier.Event? reason = Notifier.Event.Activated)
    {
        int m = minutes ?? Settings.Current.SelectedMinutes;
        if (!ApplyExecutionState()) return;
        timer.Stop();
        EndDate = null;
        if (m > 0)
        {
            EndDate = DateTime.Now.AddMinutes(m);
            timer.Interval = m * 60_000;
            timer.Start();
        }
        bool wasActive = IsActive;
        IsActive = true;
        Changed?.Invoke();
        if (!wasActive && reason is { } r) Notifier.Post(r);
    }

    public void Deactivate(Notifier.Event? reason = Notifier.Event.Deactivated)
    {
        timer.Stop();
        EndDate = null;
        SetThreadExecutionState(ES_CONTINUOUS);
        bool wasActive = IsActive;
        IsActive = false;
        Changed?.Invoke();
        if (wasActive && reason is { } r) Notifier.Post(r);
    }

    public void Toggle()
    {
        if (IsActive) Deactivate(); else Activate();
    }

    /// <summary>Re-apply after "Allow Display Sleep" changes, keeping the timer.</summary>
    public void RefreshExecutionState()
    {
        if (IsActive) ApplyExecutionState();
    }

    bool ApplyExecutionState()
    {
        var flags = ES_CONTINUOUS | ES_SYSTEM_REQUIRED;
        if (!Settings.Current.AllowDisplaySleep) flags |= ES_DISPLAY_REQUIRED;
        if (SetThreadExecutionState(flags) == 0)
        {
            Log.Write("SetThreadExecutionState failed");
            return false;
        }
        return true;
    }

    const uint ES_SYSTEM_REQUIRED = 0x00000001;
    const uint ES_DISPLAY_REQUIRED = 0x00000002;
    const uint ES_CONTINUOUS = 0x80000000;

    [DllImport("kernel32.dll")]
    static extern uint SetThreadExecutionState(uint esFlags);
}
