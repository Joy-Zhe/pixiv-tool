namespace PixivTool.Core.Models;

public sealed class DownloadProgressInfo
{
    public int Completed { get; init; }
    public int Total { get; init; }
    public int Succeeded { get; init; }
    public int Failed { get; init; }
    public string CurrentPid { get; init; } = string.Empty;
    public string Message { get; init; } = string.Empty;
}
