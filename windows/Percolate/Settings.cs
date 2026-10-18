using System.Text.Json;

namespace Percolate;

/// <summary>All persisted settings, stored as JSON in %APPDATA%\Percolate\settings.json.</summary>
sealed class Settings
{
    public static readonly int[] PresetMinutes = [0, 5, 10, 15, 30, 60, 120, 300];
    public const int LowBatteryThreshold = 20;

    public int SelectedMinutes { get; set; }                 // 0 = indefinitely
    public bool AllowDisplaySleep { get; set; }
    public bool ActivateAtLaunch { get; set; }
    public bool ActivateOnPowerConnect { get; set; }
    public bool DeactivateOnPowerDisconnect { get; set; }
    public bool DeactivateOnLowBattery { get; set; } = true;
    public bool AllowNotifications { get; set; }
    public bool HotKeyEnabled { get; set; }
    public bool ShowWelcomeAtLaunch { get; set; } = true;

    public static Settings Current { get; } = Load();

    static string FilePath => Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "Percolate", "settings.json");

    static Settings Load()
    {
        try
        {
            if (File.Exists(FilePath))
                return JsonSerializer.Deserialize<Settings>(File.ReadAllText(FilePath)) ?? new Settings();
        }
        catch (Exception e)
        {
            Log.Write($"Couldn't read settings, using defaults: {e.Message}");
        }
        return new Settings();
    }

    public void Save()
    {
        try
        {
            Directory.CreateDirectory(Path.GetDirectoryName(FilePath)!);
            File.WriteAllText(FilePath, JsonSerializer.Serialize(this, new JsonSerializerOptions { WriteIndented = true }));
        }
        catch (Exception e)
        {
            Log.Write($"Couldn't save settings: {e.Message}");
        }
    }
}

static class DurationFormat
{
    public static string Label(int minutes) => minutes switch
    {
        0 => "Indefinitely",
        < 60 => $"{minutes} minutes",
        60 => "1 hour",
        _ when minutes % 60 == 0 => $"{minutes / 60} hours",
        _ => $"{minutes / 60} h {minutes % 60} min",
    };

    public static string Until(DateTime end) =>
        end.Date == DateTime.Today ? end.ToShortTimeString() : $"{end.ToShortDateString()} {end.ToShortTimeString()}";
}

static class Log
{
    public static void Write(string message) => System.Diagnostics.Debug.WriteLine($"Percolate: {message}");
}
