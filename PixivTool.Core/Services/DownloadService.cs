using PixivTool.Core.Abstractions;
using PixivTool.Core.Exceptions;
using PixivTool.Core.Models;

namespace PixivTool.Core.Services;

public sealed class DownloadService : IDownloadService
{
    private readonly IPixivApiClient _pixivApiClient;
    private readonly HttpClient _httpClient;

    public DownloadService(IPixivApiClient pixivApiClient, HttpClient httpClient)
    {
        _pixivApiClient = pixivApiClient;
        _httpClient = httpClient;
    }

    public async Task<DownloadResult> DownloadByPidAsync(string pid, string outputPath, CancellationToken ct = default)
    {
        var info = await _pixivApiClient.GetIllustByPidAsync(pid, ct);
        return await DownloadFromUrlAsync(pid, info.OriginalUrl, outputPath, ct);
    }

    public async Task<IReadOnlyList<DownloadResult>> DownloadRankingAsync(
        RankingQuery query,
        string outputPath,
        CancellationToken ct = default)
    {
        var ranking = await _pixivApiClient.GetRankingAsync(query, ct);
        var results = new List<DownloadResult>();

        foreach (var item in ranking)
        {
            ct.ThrowIfCancellationRequested();
            var info = await _pixivApiClient.GetIllustByPidAsync(item.Pid, ct);
            results.Add(await DownloadFromUrlAsync(item.Pid, info.OriginalUrl, outputPath, ct));
        }

        return results;
    }

    private async Task<DownloadResult> DownloadFromUrlAsync(
        string pid,
        string sourceUrl,
        string outputPath,
        CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(sourceUrl))
        {
            throw new DownloadException($"PID {pid} has empty image url.");
        }

        var uri = new Uri(sourceUrl, UriKind.Absolute);
        var fileName = Path.GetFileName(uri.LocalPath);
        if (string.IsNullOrWhiteSpace(fileName))
        {
            throw new DownloadException($"Cannot resolve file name from url: {sourceUrl}");
        }

        Directory.CreateDirectory(outputPath);
        var targetFile = Path.Combine(outputPath, fileName);

        using var request = new HttpRequestMessage(HttpMethod.Get, sourceUrl);
        request.Headers.Referrer = new Uri("https://www.pixiv.net/");
        using var response = await _httpClient.SendAsync(request, ct);
        if (!response.IsSuccessStatusCode)
        {
            throw new DownloadException(
                $"Download failed for pid {pid}: {(int)response.StatusCode} {response.ReasonPhrase}");
        }

        await using var sourceStream = await response.Content.ReadAsStreamAsync(ct);
        await using var targetStream = File.Create(targetFile);
        await sourceStream.CopyToAsync(targetStream, ct);

        return new DownloadResult
        {
            Pid = pid,
            SourceUrl = sourceUrl,
            SavedPath = targetFile
        };
    }
}
