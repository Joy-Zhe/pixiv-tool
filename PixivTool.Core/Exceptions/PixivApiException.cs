namespace PixivTool.Core.Exceptions;

public sealed class PixivApiException : Exception
{
    public PixivApiException(string message) : base(message)
    {
    }
}
