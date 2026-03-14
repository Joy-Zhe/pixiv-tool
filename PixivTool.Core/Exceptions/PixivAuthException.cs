namespace PixivTool.Core.Exceptions;

public sealed class PixivAuthException : Exception
{
    public PixivAuthException(string message) : base(message)
    {
    }
}
