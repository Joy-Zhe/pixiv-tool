using System.IO;
using System.Net.Http;
using System.Threading;
using System.Threading.Tasks;
using PixivTool.Core.Abstractions;
using PixivTool.Core.Models;
using PixivTool.Core.Services;

namespace PixivTool.CoreBridge;

public static class CoreRuntime
{
    private static readonly object Sync = new();
    private static bool _initialized;

    private static readonly JsonSettingsStore SettingsStoreImpl = new("settings.json");
    private static readonly HttpClient ApiHttpClient = new();
    private static readonly HttpClient DownloadHttpClient = new();

    public static AppSettings Settings { get; private set; } = new();

    public static ISettingsStore SettingsStore => SettingsStoreImpl;
    public static IPixivApiClient ApiClient { get; } = new PixivApiClient(ApiHttpClient, () => Settings.Cookie);
    public static IDownloadService DownloadService { get; } =
        new DownloadService(ApiClient, DownloadHttpClient, () => Settings.Cookie);

    public static void EnsureInitialized()
    {
        if (_initialized)
        {
            return;
        }

        lock (Sync)
        {
            if (_initialized)
            {
                return;
            }

            Settings = SettingsStoreImpl.LoadAsync().GetAwaiter().GetResult();
            if (IsDefault(Settings) && File.Exists("settings.txt"))
            {
                var lines = File.ReadAllLines("settings.txt");
                if (lines.Length >= 3)
                {
                    Settings = new AppSettings
                    {
                        RankDownloadPath = lines[0],
                        PidDownloadPath = lines[1],
                        Cookie = lines[2]
                    };

                    SettingsStoreImpl.SaveAsync(Settings).GetAwaiter().GetResult();
                }
            }

            _initialized = true;
        }
    }

    public static Task SaveSettingsAsync(CancellationToken ct = default)
    {
        EnsureInitialized();
        return SettingsStoreImpl.SaveAsync(Settings, ct);
    }

    private static bool IsDefault(AppSettings settings)
    {
        return settings.Cookie == string.Empty &&
               settings.RankDownloadPath == "./rank/" &&
               settings.PidDownloadPath == "./pids/";
    }
}
