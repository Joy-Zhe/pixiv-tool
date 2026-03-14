namespace PixivTool.Core.Models;

public sealed class DownloadResult
{
    public string Pid { get; init; } = string.Empty;
    public string SourceUrl { get; init; } = string.Empty;
    public string SavedPath { get; init; } = string.Empty;
}
