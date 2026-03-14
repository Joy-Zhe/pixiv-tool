using System;
using System.IO;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using PixivTool.CoreBridge;
using PixivTool.Mvvm;

namespace PixivTool.ViewModels;

public sealed class PidPageViewModel : ViewModelBase
{
    private string _pid = string.Empty;
    private ImageSource? _previewImage;
    private string _pidPath = "./pids/";

    public PidPageViewModel()
    {
        CoreRuntime.EnsureInitialized();
        _pidPath = CoreRuntime.Settings.PidDownloadPath;
        PreviewCommand = new AsyncRelayCommand(PreviewAsync, () => !string.IsNullOrWhiteSpace(Pid));
        DownloadCommand = new AsyncRelayCommand(DownloadAsync, () => !string.IsNullOrWhiteSpace(Pid));
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

    public ICommand PreviewCommand { get; }
    public ICommand DownloadCommand { get; }

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
        try
        {
            var outputPath = string.IsNullOrWhiteSpace(_pidPath)
                ? CoreRuntime.Settings.PidDownloadPath
                : _pidPath;
            await CoreRuntime.DownloadService.DownloadByPidAsync(Pid.Trim(), outputPath);
            MessageBox.Show("Download complete");
        }
        catch (Exception exception)
        {
            MessageBox.Show($"Download failed: {exception.Message}");
        }
    }
}
