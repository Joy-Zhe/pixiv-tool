using System;
using System.IO;
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

    public RankPageViewModel()
    {
        CoreRuntime.EnsureInitialized();
        _rankPath = CoreRuntime.Settings.RankDownloadPath;
        DownloadCommand = new AsyncRelayCommand(DownloadAsync);
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

    public ICommand DownloadCommand { get; }

    public void SetPath(string path)
    {
        _rankPath = string.IsNullOrWhiteSpace(path) ? CoreRuntime.Settings.RankDownloadPath : path;
    }

    private async Task DownloadAsync()
    {
        try
        {
            var query = BuildQuery();
            var basePath = string.IsNullOrWhiteSpace(_rankPath)
                ? CoreRuntime.Settings.RankDownloadPath
                : _rankPath;
            var outputPath = BuildRankOutputPath(basePath, query);
            var results = await CoreRuntime.DownloadService.DownloadRankingAsync(query, outputPath);
            MessageBox.Show($"Download complete: {results.Count} files");
        }
        catch (Exception exception)
        {
            MessageBox.Show($"Rank download failed: {exception.Message}");
        }
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
}
