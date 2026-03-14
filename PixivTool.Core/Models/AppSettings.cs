namespace PixivTool.Core.Models;

public sealed class AppSettings
{
    public string Cookie { get; set; } = string.Empty;
    public string RankDownloadPath { get; set; } = "./rank/";
    public string PidDownloadPath { get; set; } = "./pids/";
}
