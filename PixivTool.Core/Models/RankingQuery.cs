namespace PixivTool.Core.Models;

public enum RankingMode
{
    Daily,
    Weekly,
    Monthly
}

public enum RankingContent
{
    All,
    Illust,
    Manga
}

public sealed class RankingQuery
{
    public RankingMode Mode { get; set; } = RankingMode.Daily;
    public RankingContent Content { get; set; } = RankingContent.All;
    public bool IsR18 { get; set; }
    public int StartPage { get; set; } = 1;
    public int EndPage { get; set; } = 10;
}
