using PixivTool.Core.Abstractions;
using PixivTool.Core.Exceptions;
using PixivTool.Core.Models;

namespace PixivTool.Core.Services;

public sealed class DownloadService : IDownloadService
{
    private const string BrowserUserAgent =
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 " +
        "(KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36";

    private readonly IPixivApiClient _pixivApiClient;
    private readonly HttpClient _httpClient;
    private readonly Func<string>? _cookieProvider;

    public DownloadService(
        IPixivApiClient pixivApiClient,
        HttpClient httpClient,
        Func<string>? cookieProvider = null)
    {
        _pixivApiClient = pixivApiClient;
        _httpClient = httpClient;
        _cookieProvider = cookieProvider;
    }

    public async Task<DownloadResult> DownloadByPidAsync(
        string pid,
        string outputPath,
        CancellationToken ct = default,
        IProgress<DownloadProgressInfo>? progress = null,
        DownloadRuntimeControl? control = null)
    {
        var pageUrls = await _pixivApiClient.GetIllustPageUrlsAsync(pid, ct);
        var total = pageUrls.Count;
        var succeeded = 0;
        var completed = 0;
        var failed = 0;
        string? firstFailureMessage = null;
        var isMultiPage = total > 1;
        var targetPath = isMultiPage ? Path.Combine(outputPath, pid) : outputPath;
        DownloadResult? firstResult = null;

        foreach (var url in pageUrls)
        {
            await WaitIfPausedOrCancelledAsync(control, ct);
            progress?.Report(new DownloadProgressInfo
            {
                Completed = completed,
                Total = total,
                Succeeded = succeeded,
                Failed = failed,
                CurrentPid = pid,
                Message = $"Downloading page {completed + 1}/{total}..."
            });

            try
            {
                var result = await DownloadFromUrlAsync(pid, url, targetPath, ct);
                firstResult ??= result;
                succeeded++;
            }
            catch (Exception ex)
            {
                // Keep downloading remaining pages for this pid.
                failed++;
                firstFailureMessage ??= ex.Message;
            }
            finally
            {
                completed++;
            }
        }

        if (firstResult is null)
        {
            throw new DownloadException($"Download failed for pid {pid}.");
        }

        if (failed > 0)
        {
            throw new DownloadException(
                $"Partial success for pid {pid}: downloaded {succeeded}/{total} pages. " +
                $"First error: {firstFailureMessage}");
        }

        progress?.Report(new DownloadProgressInfo
        {
            Completed = completed,
            Total = total,
            Succeeded = succeeded,
            Failed = failed,
            CurrentPid = pid,
            Message = isMultiPage ? $"Completed. Saved to folder: {targetPath}" : "Download completed."
        });

        return isMultiPage
            ? new DownloadResult
            {
                Pid = pid,
                SourceUrl = firstResult.SourceUrl,
                SavedPath = targetPath
            }
            : firstResult;
    }

    public async Task<IReadOnlyList<DownloadResult>> DownloadRankingAsync(
        RankingQuery query,
        string outputPath,
        CancellationToken ct = default,
        IProgress<DownloadProgressInfo>? progress = null,
        DownloadRuntimeControl? control = null)
    {
        var ranking = await _pixivApiClient.GetRankingAsync(query, ct);
        var results = new List<DownloadResult>();
        var processed = 0;
        var total = ranking.Count;

        foreach (var item in ranking)
        {
            await WaitIfPausedOrCancelledAsync(control, ct);
            ct.ThrowIfCancellationRequested();
            processed++;
            try
            {
                progress?.Report(new DownloadProgressInfo
                {
                    Completed = processed - 1,
                    Total = total,
                    Succeeded = results.Count,
                    Failed = (processed - 1) - results.Count,
                    CurrentPid = item.Pid,
                    Message = $"Downloading PID {item.Pid}..."
                });

                // Reuse PID download pipeline so multi-page illusts are archived by pid folder.
                var result = await DownloadByPidAsync(item.Pid, outputPath, ct, null, control);
                results.Add(result);

                progress?.Report(new DownloadProgressInfo
                {
                    Completed = processed,
                    Total = total,
                    Succeeded = results.Count,
                    Failed = processed - results.Count,
                    CurrentPid = item.Pid,
                    Message = $"Downloaded PID {item.Pid}."
                });
            }
            catch
            {
                // Ignore single-item failures (deleted/restricted/403) and continue the batch.
                progress?.Report(new DownloadProgressInfo
                {
                    Completed = processed,
                    Total = total,
                    Succeeded = results.Count,
                    Failed = processed - results.Count,
                    CurrentPid = item.Pid,
                    Message = $"Skipped PID {item.Pid}."
                });
            }
        }

        if (results.Count == 0)
        {
            throw new DownloadException(
                "All ranking items failed to download. Check cookie validity and account permissions.");
        }

        return results;
    }

    private static async Task WaitIfPausedOrCancelledAsync(DownloadRuntimeControl? control, CancellationToken ct)
    {
        if (control is null)
        {
            ct.ThrowIfCancellationRequested();
            return;
        }

        while (control.IsPaused)
        {
            if (control.IsCancelled)
            {
                throw new OperationCanceledException("Download cancelled by user.");
            }

            ct.ThrowIfCancellationRequested();
            await Task.Delay(120, ct);
        }

        if (control.IsCancelled)
        {
            throw new OperationCanceledException("Download cancelled by user.");
        }

        ct.ThrowIfCancellationRequested();
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
        request.Headers.TryAddWithoutValidation("User-Agent", BrowserUserAgent);
        request.Headers.TryAddWithoutValidation("Accept", "image/avif,image/webp,image/apng,image/*,*/*;q=0.8");
        request.Headers.TryAddWithoutValidation("Accept-Language", "zh-CN,zh;q=0.9,en;q=0.8");
        request.Headers.TryAddWithoutValidation("Origin", "https://www.pixiv.net");
        request.Headers.Referrer = new Uri("https://www.pixiv.net/");
        if (_cookieProvider is not null)
        {
            request.Headers.TryAddWithoutValidation("Cookie", _cookieProvider());
        }
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
