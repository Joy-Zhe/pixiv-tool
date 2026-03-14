using PixivTool.Core.Models;

namespace PixivTool.Core.Abstractions;

public interface IPixivApiClient
{
    Task<IllustInfo> GetIllustByPidAsync(string pid, CancellationToken ct = default);
    Task<IReadOnlyList<RankingItem>> GetRankingAsync(RankingQuery query, CancellationToken ct = default);
    Task<Stream> GetPreviewImageAsync(string pid, CancellationToken ct = default);
}
