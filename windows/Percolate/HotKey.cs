using System.Runtime.InteropServices;

namespace Percolate;

/// <summary>A single global shortcut, Ctrl+Alt+P, registered with RegisterHotKey.</summary>
sealed class HotKey : NativeWindow, IDisposable
{
    public const string Display = "Ctrl+Alt+P";

    readonly Action action;
    bool registered;

    public HotKey(Action action)
    {
        this.action = action;
        CreateHandle(new CreateParams());
    }

    /// <summary>Registers or unregisters to match the setting. Returns false if another app owns the shortcut.</summary>
    public bool Apply(bool enabled)
    {
        if (registered) UnregisterHotKey(Handle, Id);
        registered = enabled && RegisterHotKey(Handle, Id, MOD_CONTROL | MOD_ALT | MOD_NOREPEAT, (uint)Keys.P);
        if (enabled && !registered) Log.Write($"RegisterHotKey failed: {Marshal.GetLastWin32Error()}");
        return registered == enabled;
    }

    protected override void WndProc(ref Message m)
    {
        if (m.Msg == WM_HOTKEY && (int)m.WParam == Id) action();
        base.WndProc(ref m);
    }

    public void Dispose()
    {
        Apply(false);
        DestroyHandle();
    }

    const int Id = 1;
    const int WM_HOTKEY = 0x0312;
    const uint MOD_ALT = 0x0001;
    const uint MOD_CONTROL = 0x0002;
    const uint MOD_NOREPEAT = 0x4000;

    [DllImport("user32.dll", SetLastError = true)]
    static extern bool RegisterHotKey(IntPtr hWnd, int id, uint fsModifiers, uint vk);

    [DllImport("user32.dll", SetLastError = true)]
    static extern bool UnregisterHotKey(IntPtr hWnd, int id);
}
