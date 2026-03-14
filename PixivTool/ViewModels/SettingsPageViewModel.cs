using System;
using System.Threading.Tasks;
using System.Windows.Input;
using Forms = System.Windows.Forms;
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

        ApplyRankPathCommand = new RelayCommand(BrowseRankPath);
        ApplyPidPathCommand = new RelayCommand(BrowsePidPath);
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

    private void BrowseRankPath()
    {
        var selectedPath = SelectFolderPath("Select rank download folder", RankDownloadPath);
        if (string.IsNullOrWhiteSpace(selectedPath))
        {
            return;
        }

        RankDownloadPath = selectedPath;
        RankPathApplied?.Invoke(RankDownloadPath);
    }

    private void BrowsePidPath()
    {
        var selectedPath = SelectFolderPath("Select PID download folder", PidDownloadPath);
        if (string.IsNullOrWhiteSpace(selectedPath))
        {
            return;
        }

        PidDownloadPath = selectedPath;
        PidPathApplied?.Invoke(PidDownloadPath);
    }

    private static string? SelectFolderPath(string title, string defaultPath)
    {
        using var dialog = new Forms.FolderBrowserDialog
        {
            Description = title,
            UseDescriptionForTitle = true,
            InitialDirectory = string.IsNullOrWhiteSpace(defaultPath)
                ? Environment.CurrentDirectory
                : defaultPath
        };

        var result = dialog.ShowDialog();
        return result == Forms.DialogResult.OK ? dialog.SelectedPath : null;
    }

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
            System.Windows.MessageBox.Show("Settings Saved");
        }
        catch (Exception ex)
        {
            System.Windows.MessageBox.Show($"Failed:{ex.Message}");
        }
    }
}
