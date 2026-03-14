namespace PixivTool.Core.Models;

public sealed class RankingItem
{
    public string Pid { get; init; } = string.Empty;
    public int Rank { get; init; }
    public string Title { get; init; } = string.Empty;
}
