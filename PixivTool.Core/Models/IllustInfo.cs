namespace PixivTool.Core.Models;

public sealed class IllustInfo
{
    public string Pid { get; init; } = string.Empty;
    public string OriginalUrl { get; init; } = string.Empty;
    public string ThumbUrl { get; init; } = string.Empty;
    public string Title { get; init; } = string.Empty;
}
