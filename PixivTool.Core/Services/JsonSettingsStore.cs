using System.Text.Json;
using PixivTool.Core.Abstractions;
using PixivTool.Core.Models;

namespace PixivTool.Core.Services;

public sealed class JsonSettingsStore : ISettingsStore
{
    private readonly string _settingsFilePath;
    private static readonly JsonSerializerOptions SerializerOptions = new(JsonSerializerDefaults.Web)
    {
        WriteIndented = true
    };

    public JsonSettingsStore(string settingsFilePath = "settings.json")
    {
        _settingsFilePath = settingsFilePath;
    }

    public async Task<AppSettings> LoadAsync(CancellationToken ct = default)
    {
        if (!File.Exists(_settingsFilePath))
        {
            return new AppSettings();
        }

        await using var stream = File.OpenRead(_settingsFilePath);
        var settings = await JsonSerializer.DeserializeAsync<AppSettings>(stream, SerializerOptions, ct)
            .ConfigureAwait(false);
        return settings ?? new AppSettings();
    }

    public async Task SaveAsync(AppSettings settings, CancellationToken ct = default)
    {
        var parent = Path.GetDirectoryName(Path.GetFullPath(_settingsFilePath));
        if (!string.IsNullOrWhiteSpace(parent))
        {
            Directory.CreateDirectory(parent);
        }

        await using var stream = File.Create(_settingsFilePath);
        await JsonSerializer.SerializeAsync(stream, settings, SerializerOptions, ct)
            .ConfigureAwait(false);
    }
}
