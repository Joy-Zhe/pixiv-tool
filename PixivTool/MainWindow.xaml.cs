using System.Collections.Generic;
using System.Windows;
using System.Windows.Controls;
using PixivTool.CoreBridge;
using PixivTool.ViewModels;

namespace PixivTool;

public partial class MainWindow : Window
{
    private readonly MainWindowViewModel _viewModel;
    private static readonly Dictionary<string, Page> BufferPages = new();

    private string _rankDownloadPath = "./rank/";
    private string _pidDownloadPath = "./pids/";

    public MainWindow()
    {
        InitializeComponent();

        CoreRuntime.EnsureInitialized();
        _rankDownloadPath = CoreRuntime.Settings.RankDownloadPath;
        _pidDownloadPath = CoreRuntime.Settings.PidDownloadPath;

        _viewModel = new MainWindowViewModel();
        _viewModel.NavigateRequested += NavigateTo;
        DataContext = _viewModel;

        var settingsPage = GetOrCreateSettingsPage();
        settingsPage.RankPathChanged += SetRankPath;
        settingsPage.PidPathChanged += SetPidPath;
    }

    private void SetRankPath(string path)
    {
        _rankDownloadPath = path;
    }

    private void SetPidPath(string path)
    {
        _pidDownloadPath = path;
    }

    private void NavigateTo(string pageKey)
    {
        switch (pageKey)
        {
            case "Rank":
            {
                _rankDownloadPath = CoreRuntime.Settings.RankDownloadPath;
                var page = GetOrCreateRankPage();
                page.SetPath(_rankDownloadPath);
                currentFrame.Navigate(page);
                break;
            }
            case "Pid":
            {
                _pidDownloadPath = CoreRuntime.Settings.PidDownloadPath;
                var page = GetOrCreatePidPage();
                page.SetPath(_pidDownloadPath);
                currentFrame.Navigate(page);
                break;
            }
            case "Settings":
                currentFrame.Navigate(GetOrCreateSettingsPage());
                break;
            case "Star":
                currentFrame.Navigate(GetOrCreateStarPage());
                break;
        }
    }

    private static RankPage GetOrCreateRankPage()
    {
        if (!BufferPages.TryGetValue("Rank", out var page))
        {
            page = new RankPage();
            BufferPages.Add("Rank", page);
        }

        return (RankPage)page;
    }

    private static PidPage GetOrCreatePidPage()
    {
        if (!BufferPages.TryGetValue("Pid", out var page))
        {
            page = new PidPage();
            BufferPages.Add("Pid", page);
        }

        return (PidPage)page;
    }

    private static SettingsPage GetOrCreateSettingsPage()
    {
        if (!BufferPages.TryGetValue("Settings", out var page))
        {
            page = new SettingsPage();
            BufferPages.Add("Settings", page);
        }

        return (SettingsPage)page;
    }

    private static StarPage GetOrCreateStarPage()
    {
        if (!BufferPages.TryGetValue("Star", out var page))
        {
            page = new StarPage();
            BufferPages.Add("Star", page);
        }

        return (StarPage)page;
    }
}
