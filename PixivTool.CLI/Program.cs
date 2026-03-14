using PixivTool.Core.Abstractions;
using PixivTool.Core.Models;
using PixivTool.Core.Services;

var settingsStore = new JsonSettingsStore();
var settings = await settingsStore.LoadAsync();

using var apiHttpClient = new HttpClient();
using var downloadHttpClient = new HttpClient();
IPixivApiClient apiClient = new PixivApiClient(apiHttpClient, () => settings.Cookie);
IDownloadService downloadService = new DownloadService(apiClient, downloadHttpClient, () => settings.Cookie);

if (args.Length == 0)
{
    PrintHelp();
    return;
}

var command = args[0].ToLowerInvariant();
try
{
    switch (command)
    {
        case "settings":
            await HandleSettingsAsync(args[1..], settings, settingsStore);
            break;
        case "pid":
            await HandlePidAsync(args[1..], settings, downloadService);
            break;
        case "rank":
            await HandleRankAsync(args[1..], settings, downloadService);
            break;
        default:
            PrintHelp();
            break;
    }
}
catch (Exception ex)
{
    Console.Error.WriteLine($"[ERROR] {ex.Message}");
    Environment.ExitCode = 1;
}

static async Task HandleSettingsAsync(string[] args, AppSettings settings, ISettingsStore settingsStore)
{
    for (var i = 0; i < args.Length; i++)
    {
        var arg = args[i];
        if (arg == "--cookie" && i + 1 < args.Length)
        {
            settings.Cookie = args[++i];
            continue;
        }

        if (arg == "--rank-path" && i + 1 < args.Length)
        {
            settings.RankDownloadPath = args[++i];
            continue;
        }

        if (arg == "--pid-path" && i + 1 < args.Length)
        {
            settings.PidDownloadPath = args[++i];
            continue;
        }
    }

    await settingsStore.SaveAsync(settings);
    Console.WriteLine("Settings saved.");
}

static async Task HandlePidAsync(string[] args, AppSettings settings, IDownloadService downloadService)
{
    if (args.Length == 0)
    {
        Console.WriteLine("Usage: pid <pid> [--output <path>]");
        return;
    }

    var pid = args[0];
    var outputPath = settings.PidDownloadPath;

    for (var i = 1; i < args.Length; i++)
    {
        if (args[i] == "--output" && i + 1 < args.Length)
        {
            outputPath = args[++i];
        }
    }

    var result = await downloadService.DownloadByPidAsync(pid, outputPath);
    Console.WriteLine($"Downloaded PID {result.Pid} -> {result.SavedPath}");
}

static async Task HandleRankAsync(string[] args, AppSettings settings, IDownloadService downloadService)
{
    var query = new RankingQuery();
    var outputPath = settings.RankDownloadPath;

    for (var i = 0; i < args.Length; i++)
    {
        if (args[i] == "--mode" && i + 1 < args.Length)
        {
            var mode = args[++i].ToLowerInvariant();
            query.Mode = mode switch
            {
                "weekly" => RankingMode.Weekly,
                "monthly" => RankingMode.Monthly,
                _ => RankingMode.Daily
            };
            continue;
        }

        if (args[i] == "--content" && i + 1 < args.Length)
        {
            var content = args[++i].ToLowerInvariant();
            query.Content = content switch
            {
                "illust" => RankingContent.Illust,
                "manga" => RankingContent.Manga,
                _ => RankingContent.All
            };
            continue;
        }

        if (args[i] == "--r18")
        {
            query.IsR18 = true;
            continue;
        }

        if (args[i] == "--start" && i + 1 < args.Length && int.TryParse(args[++i], out var start))
        {
            query.StartPage = start;
            continue;
        }

        if (args[i] == "--end" && i + 1 < args.Length && int.TryParse(args[++i], out var end))
        {
            query.EndPage = end;
            continue;
        }

        if (args[i] == "--output" && i + 1 < args.Length)
        {
            outputPath = args[++i];
        }
    }

    var results = await downloadService.DownloadRankingAsync(query, outputPath);
    Console.WriteLine($"Downloaded {results.Count} files to {outputPath}");
}

static void PrintHelp()
{
    Console.WriteLine("PixivTool.CLI");
    Console.WriteLine("  settings --cookie <value> --rank-path <path> --pid-path <path>");
    Console.WriteLine("  pid <pid> [--output <path>]");
    Console.WriteLine("  rank [--mode daily|weekly|monthly] [--content all|illust|manga] [--r18] [--start N] [--end N] [--output <path>]");
}
