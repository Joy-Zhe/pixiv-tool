using PixivTool.Core.Models;
using PixivTool.Core.Services;

namespace PixivTool.Tests;

public sealed class JsonSettingsStoreTests
{
    [Fact]
    public async Task SaveAndLoad_RoundTrip_ShouldKeepValues()
    {
        var tempFile = Path.Combine(Path.GetTempPath(), $"pixivtool-settings-{Guid.NewGuid():N}.json");
        try
        {
            var store = new JsonSettingsStore(tempFile);
            var original = new AppSettings
            {
                Cookie = "PHPSESSID=test-cookie",
                RankDownloadPath = @"E:\rank",
                PidDownloadPath = @"E:\pid"
            };

            await store.SaveAsync(original);
            var loaded = await store.LoadAsync();

            Assert.Equal(original.Cookie, loaded.Cookie);
            Assert.Equal(original.RankDownloadPath, loaded.RankDownloadPath);
            Assert.Equal(original.PidDownloadPath, loaded.PidDownloadPath);
        }
        finally
        {
            if (File.Exists(tempFile))
            {
                File.Delete(tempFile);
            }
        }
    }
}
