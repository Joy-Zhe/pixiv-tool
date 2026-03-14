using System;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Input;
using PixivTool.CoreBridge;
using PixivTool.Mvvm;

namespace PixivTool.ViewModels;

public sealed class SettingsPageViewModel : ViewModelBase
{
    private string _rankDownloadPath = string.Empty;
    private string _pidDownloadPath = string.Empty;
    private string _cookieRawMessage = string.Empty;

    public SettingsPageViewModel()
    {
        CoreRuntime.EnsureInitialized();
        _rankDownloadPath = CoreRuntime.Settings.RankDownloadPath;
        _pidDownloadPath = CoreRuntime.Settings.PidDownloadPath;
        _cookieRawMessage = CoreRuntime.Settings.Cookie;

        ApplyRankPathCommand = new RelayCommand(() => RankPathApplied?.Invoke(RankDownloadPath));
        ApplyPidPathCommand = new RelayCommand(() => PidPathApplied?.Invoke(PidDownloadPath));
        SaveCommand = new AsyncRelayCommand(SaveAsync);
    }

    public event Action<string>? RankPathApplied;
    public event Action<string>? PidPathApplied;

    public string RankDownloadPath
    {
        get => _rankDownloadPath;
        set => SetProperty(ref _rankDownloadPath, value);
    }

    public string PidDownloadPath
    {
        get => _pidDownloadPath;
        set => SetProperty(ref _pidDownloadPath, value);
    }

    public string CookieRawMessage
    {
        get => _cookieRawMessage;
        set => SetProperty(ref _cookieRawMessage, value);
    }

    public ICommand ApplyRankPathCommand { get; }
    public ICommand ApplyPidPathCommand { get; }
    public ICommand SaveCommand { get; }

    private async Task SaveAsync()
    {
        try
        {
            CoreRuntime.Settings.RankDownloadPath = RankDownloadPath;
            CoreRuntime.Settings.PidDownloadPath = PidDownloadPath;
            CoreRuntime.Settings.Cookie = CookieRawMessage;

            RankPathApplied?.Invoke(RankDownloadPath);
            PidPathApplied?.Invoke(PidDownloadPath);

            await CoreRuntime.SaveSettingsAsync();
            MessageBox.Show("Settings Saved");
        }
        catch (Exception ex)
        {
            MessageBox.Show($"Failed:{ex.Message}");
        }
    }
}
