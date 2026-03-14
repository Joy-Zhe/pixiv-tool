using System.Net;
using PixivTool.Core.Abstractions;
using PixivTool.Core.Models;
using PixivTool.Core.Services;

namespace PixivTool.Tests;

public sealed class DownloadServiceTests
{
    [Fact]
    public async Task DownloadByPidAsync_ShouldSaveFile()
    {
        var tempDir = Path.Combine(Path.GetTempPath(), $"pixivtool-download-{Guid.NewGuid():N}");
        Directory.CreateDirectory(tempDir);

        try
        {
            var apiClient = new StubPixivApiClient();
            var handler = new FakeHttpMessageHandler(_ =>
                Task.FromResult(new HttpResponseMessage(HttpStatusCode.OK)
                {
                    Content = new ByteArrayContent(new byte[] { 1, 2, 3, 4 })
                }));

            using var httpClient = new HttpClient(handler);
            var service = new DownloadService(apiClient, httpClient);

            var result = await service.DownloadByPidAsync("123", tempDir);

            Assert.True(File.Exists(result.SavedPath));
            Assert.Equal("123", result.Pid);
            Assert.EndsWith("_p0.jpg", result.SavedPath, StringComparison.OrdinalIgnoreCase);
        }
        finally
        {
            if (Directory.Exists(tempDir))
            {
                Directory.Delete(tempDir, true);
            }
        }
    }

    private sealed class StubPixivApiClient : IPixivApiClient
    {
        public Task<IllustInfo> GetIllustByPidAsync(string pid, CancellationToken ct = default)
        {
            return Task.FromResult(new IllustInfo
            {
                Pid = pid,
                OriginalUrl = "https://i.pximg.net/img-original/img/2026/01/01/00/00/00/123_p0.jpg",
                ThumbUrl = "https://i.pximg.net/c/250x250_80_a2/img-master/img/2026/01/01/00/00/00/123_p0_square1200.jpg",
                Title = "test"
            });
        }

        public Task<IReadOnlyList<string>> GetIllustPageUrlsAsync(string pid, CancellationToken ct = default)
        {
            IReadOnlyList<string> result = new List<string>
            {
                "https://i.pximg.net/img-original/img/2026/01/01/00/00/00/123_p0.jpg"
            };
            return Task.FromResult(result);
        }

        public Task<IReadOnlyList<RankingItem>> GetRankingAsync(RankingQuery query, CancellationToken ct = default)
        {
            IReadOnlyList<RankingItem> result = new List<RankingItem>();
            return Task.FromResult(result);
        }

        public Task<Stream> GetPreviewImageAsync(string pid, CancellationToken ct = default)
        {
            return Task.FromResult<Stream>(new MemoryStream(new byte[] { 1, 2, 3 }));
        }
    }
}
