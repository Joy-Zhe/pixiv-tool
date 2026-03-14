using PixivTool.Core.Models;

namespace PixivTool.Core.Abstractions;

public interface IDownloadService
{
    Task<DownloadResult> DownloadByPidAsync(string pid, string outputPath, CancellationToken ct = default);
    Task<IReadOnlyList<DownloadResult>> DownloadRankingAsync(RankingQuery query, string outputPath, CancellationToken ct = default);
}
