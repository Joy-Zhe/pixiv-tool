namespace PixivTool.Core.Exceptions;

public sealed class DownloadException : Exception
{
    public DownloadException(string message) : base(message)
    {
    }
}
