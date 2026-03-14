using System;
using System.IO;
using System.Threading;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using PixivTool.Core.Models;
using PixivTool.CoreBridge;
using PixivTool.Mvvm;

namespace PixivTool.ViewModels;

public sealed class PidPageViewModel : ViewModelBase
{
    private string _pid = string.Empty;
    private ImageSource? _previewImage;
    private string _pidPath = "./pids/";

    private bool _isDownloading;
    private bool _isPaused;
    private int _progressValue;
    private int _progressMaximum = 100;
    private string _progressText = "Ready.";

    private CancellationTokenSource? _downloadCts;
    private DownloadRuntimeControl? _runtimeControl;
    private int _lastCompleted;
    private int _lastTotal;
    private int _lastSucceeded;
    private int _lastFailed;

    public PidPageViewModel()
    {
        CoreRuntime.EnsureInitialized();
        _pidPath = CoreRuntime.Settings.PidDownloadPath;
        PreviewCommand = new AsyncRelayCommand(PreviewAsync, () => !string.IsNullOrWhiteSpace(Pid));
        DownloadCommand = new AsyncRelayCommand(DownloadAsync, () => !string.IsNullOrWhiteSpace(Pid) && !IsDownloading);
        PauseResumeCommand = new RelayCommand(TogglePauseResume, () => IsDownloading);
        CancelCommand = new RelayCommand(CancelDownload, () => IsDownloading);
    }

    public string Pid
    {
        get => _pid;
        set
        {
            if (SetProperty(ref _pid, value))
            {
                (PreviewCommand as AsyncRelayCommand)?.RaiseCanExecuteChanged();
                (DownloadCommand as AsyncRelayCommand)?.RaiseCanExecuteChanged();
            }
        }
    }

    public ImageSource? PreviewImage
    {
        get => _previewImage;
        private set => SetProperty(ref _previewImage, value);
    }

    public bool IsDownloading
    {
        get => _isDownloading;
        private set
        {
            if (SetProperty(ref _isDownloading, value))
            {
                (DownloadCommand as AsyncRelayCommand)?.RaiseCanExecuteChanged();
                (PauseResumeCommand as RelayCommand)?.RaiseCanExecuteChanged();
                (CancelCommand as RelayCommand)?.RaiseCanExecuteChanged();
            }
        }
    }

    public int ProgressValue
    {
        get => _progressValue;
        private set => SetProperty(ref _progressValue, value);
    }

    public int ProgressMaximum
    {
        get => _progressMaximum;
        private set => SetProperty(ref _progressMaximum, value);
    }

    public string ProgressText
    {
        get => _progressText;
        private set => SetProperty(ref _progressText, value);
    }

    public string PauseResumeText => _isPaused ? "Resume" : "Pause";

    public ICommand PreviewCommand { get; }
    public ICommand DownloadCommand { get; }
    public ICommand PauseResumeCommand { get; }
    public ICommand CancelCommand { get; }

    public void SetPath(string path)
    {
        _pidPath = string.IsNullOrWhiteSpace(path) ? CoreRuntime.Settings.PidDownloadPath : path;
    }

    private async Task PreviewAsync()
    {
        try
        {
            Stream imageStream = await CoreRuntime.ApiClient.GetPreviewImageAsync(Pid.Trim());
            var bitmapImage = new BitmapImage();
            bitmapImage.BeginInit();
            bitmapImage.CacheOption = BitmapCacheOption.OnLoad;
            bitmapImage.StreamSource = imageStream;
            bitmapImage.EndInit();
            bitmapImage.Freeze();
            PreviewImage = bitmapImage;
        }
        catch (Exception exception)
        {
            MessageBox.Show($"Preview failed: {exception.Message}");
        }
    }

    private async Task DownloadAsync()
    {
        if (IsDownloading)
        {
            return;
        }

        IsDownloading = true;
        _isPaused = false;
        RaisePropertyChanged(nameof(PauseResumeText));

        ProgressValue = 0;
        ProgressMaximum = 100;
        ProgressText = "Preparing PID download...";
        _lastCompleted = 0;
        _lastTotal = 0;
        _lastSucceeded = 0;
        _lastFailed = 0;

        try
        {
            var outputPath = string.IsNullOrWhiteSpace(_pidPath)
                ? CoreRuntime.Settings.PidDownloadPath
                : _pidPath;

            _downloadCts = new CancellationTokenSource();
            _runtimeControl = new DownloadRuntimeControl();

            var progress = new Progress<DownloadProgressInfo>(info =>
            {
                ProgressMaximum = Math.Max(1, info.Total);
                ProgressValue = Math.Min(info.Completed, ProgressMaximum);
                _lastCompleted = info.Completed;
                _lastTotal = info.Total;
                _lastSucceeded = info.Succeeded;
                _lastFailed = info.Failed;
                ProgressText = $"{info.Message} ({info.Completed}/{info.Total}, success {info.Succeeded}, failed {info.Failed})";
            });

            await CoreRuntime.DownloadService.DownloadByPidAsync(
                Pid.Trim(),
                outputPath,
                _downloadCts.Token,
                progress,
                _runtimeControl);

            ProgressValue = ProgressMaximum;
            ProgressText = "Download completed.";
            MessageBox.Show("Download complete");
        }
        catch (OperationCanceledException)
        {
            ProgressText = $"Download cancelled. ({_lastCompleted}/{_lastTotal}, success {_lastSucceeded}, failed {_lastFailed})";
        }
        catch (Exception exception)
        {
            ProgressText = "Download failed.";
            MessageBox.Show($"Download failed: {exception.Message}");
        }
        finally
        {
            _runtimeControl = null;
            _downloadCts?.Dispose();
            _downloadCts = null;
            IsDownloading = false;
            _isPaused = false;
            RaisePropertyChanged(nameof(PauseResumeText));
        }
    }

    private void TogglePauseResume()
    {
        if (!IsDownloading || _runtimeControl is null)
        {
            return;
        }

        if (_isPaused)
        {
            _runtimeControl.Resume();
            _isPaused = false;
            ProgressText = "Resuming...";
        }
        else
        {
            _runtimeControl.Pause();
            _isPaused = true;
            ProgressText = "Paused.";
        }

        RaisePropertyChanged(nameof(PauseResumeText));
    }

    private void CancelDownload()
    {
        if (!IsDownloading)
        {
            return;
        }

        _runtimeControl?.Cancel();
        _downloadCts?.Cancel();
        ProgressText = "Cancelling...";
    }
}
