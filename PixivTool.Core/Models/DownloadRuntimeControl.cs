namespace PixivTool.Core.Models;

public sealed class DownloadRuntimeControl
{
    private volatile bool _isPaused;
    private volatile bool _isCancelled;

    public bool IsPaused => _isPaused;
    public bool IsCancelled => _isCancelled;

    public void Pause()
    {
        _isPaused = true;
    }

    public void Resume()
    {
        _isPaused = false;
    }

    public void Cancel()
    {
        _isCancelled = true;
    }
}
