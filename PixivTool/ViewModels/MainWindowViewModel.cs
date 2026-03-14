using System;
using System.Windows.Input;
using PixivTool.Mvvm;

namespace PixivTool.ViewModels;

public sealed class MainWindowViewModel : ViewModelBase
{
    public MainWindowViewModel()
    {
        OpenRankCommand = new RelayCommand(() => NavigateRequested?.Invoke("Rank"));
        OpenPidCommand = new RelayCommand(() => NavigateRequested?.Invoke("Pid"));
        OpenStarCommand = new RelayCommand(() => NavigateRequested?.Invoke("Star"));
        OpenSettingsCommand = new RelayCommand(() => NavigateRequested?.Invoke("Settings"));
    }

    public event Action<string>? NavigateRequested;

    public ICommand OpenRankCommand { get; }
    public ICommand OpenPidCommand { get; }
    public ICommand OpenStarCommand { get; }
    public ICommand OpenSettingsCommand { get; }
}
