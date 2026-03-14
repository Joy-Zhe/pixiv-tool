using System;
using System.IO;
using System.Threading;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Input;
using PixivTool.Core.Models;
using PixivTool.CoreBridge;
using PixivTool.Mvvm;

namespace PixivTool.ViewModels;

public sealed class RankPageViewModel : ViewModelBase
{
    private int _selectedDownloadOption;
    private int _selectedTimeSpan;
    private bool _isR18;
    private string _rankPath = "./rank/";

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

    public RankPageViewModel()
    {
        CoreRuntime.EnsureInitialized();
        _rankPath = CoreRuntime.Settings.RankDownloadPath;

        DownloadCommand = new AsyncRelayCommand(DownloadAsync, () => !IsDownloading);
        PauseResumeCommand = new RelayCommand(TogglePauseResume, () => IsDownloading);
        CancelCommand = new RelayCommand(CancelDownload, () => IsDownloading);
    }

    public int SelectedDownloadOption
    {
        get => _selectedDownloadOption;
        set => SetProperty(ref _selectedDownloadOption, value);
    }

    public int SelectedTimeSpan
    {
        get => _selectedTimeSpan;
        set => SetProperty(ref _selectedTimeSpan, value);
    }

    public bool IsR18
    {
        get => _isR18;
        set => SetProperty(ref _isR18, value);
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

    public bool IsDownloading
    {
        get => _isDownloading;
        private set
        {
            if (SetProperty(ref _isDownloading, value))
            {
                RaiseCommandStates();
            }
        }
    }

    public string PauseResumeText => _isPaused ? "Resume" : "Pause";

    public ICommand DownloadCommand { get; }
    public ICommand PauseResumeCommand { get; }
    public ICommand CancelCommand { get; }

    public void SetPath(string path)
    {
        _rankPath = string.IsNullOrWhiteSpace(path) ? CoreRuntime.Settings.RankDownloadPath : path;
    }

    private async Task DownloadAsync()
    {
        if (IsDownloading)
        {
            return;
        }

        IsDownloading = true;
        _isPaused = false;
        OnPauseResumeChanged();
        ProgressValue = 0;
        ProgressMaximum = 100;
        ProgressText = "Preparing ranking download...";
        _lastCompleted = 0;
        _lastTotal = 0;
        _lastSucceeded = 0;
        _lastFailed = 0;

        _downloadCts = new CancellationTokenSource();
        _runtimeControl = new DownloadRuntimeControl();

        try
        {
            var query = BuildQuery();
            var basePath = string.IsNullOrWhiteSpace(_rankPath)
                ? CoreRuntime.Settings.RankDownloadPath
                : _rankPath;
            var outputPath = BuildRankOutputPath(basePath, query);

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

            var results = await CoreRuntime.DownloadService.DownloadRankingAsync(
                query,
                outputPath,
                _downloadCts.Token,
                progress,
                _runtimeControl);

            ProgressValue = ProgressMaximum;
            ProgressText = $"Completed: {results.Count} items downloaded.";
            MessageBox.Show($"Download complete: {results.Count} items");
        }
        catch (OperationCanceledException)
        {
            ProgressText = $"Download cancelled. ({_lastCompleted}/{_lastTotal}, success {_lastSucceeded}, failed {_lastFailed})";
        }
        catch (Exception exception)
        {
            ProgressText = "Download failed.";
            MessageBox.Show(
                $"Rank download failed: {exception.Message}\n\n" +
                "Please verify Cookie in Settings, then try again.");
        }
        finally
        {
            _runtimeControl = null;
            _downloadCts?.Dispose();
            _downloadCts = null;
            IsDownloading = false;
            _isPaused = false;
            OnPauseResumeChanged();
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

        OnPauseResumeChanged();
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

    private RankingQuery BuildQuery()
    {
        return new RankingQuery
        {
            IsR18 = IsR18,
            Content = SelectedDownloadOption switch
            {
                1 => RankingContent.Illust,
                2 => RankingContent.Manga,
                _ => RankingContent.All
            },
            Mode = SelectedTimeSpan switch
            {
                1 => RankingMode.Weekly,
                _ => RankingMode.Daily
            }
        };
    }

    private static string BuildRankOutputPath(string basePath, RankingQuery query)
    {
        var path = basePath;

        if (query.Content == RankingContent.Illust)
        {
            path = Path.Combine(path, "illust");
        }
        else if (query.Content == RankingContent.Manga)
        {
            path = Path.Combine(path, "manga");
        }

        if (query.IsR18)
        {
            path = Path.Combine(path, "R18");
        }

        return path;
    }

    private void RaiseCommandStates()
    {
        (DownloadCommand as AsyncRelayCommand)?.RaiseCanExecuteChanged();
        (PauseResumeCommand as RelayCommand)?.RaiseCanExecuteChanged();
        (CancelCommand as RelayCommand)?.RaiseCanExecuteChanged();
    }

    private void OnPauseResumeChanged()
    {
        RaisePropertyChanged(nameof(PauseResumeText));
        (PauseResumeCommand as RelayCommand)?.RaiseCanExecuteChanged();
    }
}
