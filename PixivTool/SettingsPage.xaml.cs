using System.Windows.Controls;
using PixivTool.ViewModels;

namespace PixivTool;

public partial class SettingsPage : Page
{
    private readonly SettingsPageViewModel _viewModel;

    public SettingsPage()
    {
        InitializeComponent();
        _viewModel = new SettingsPageViewModel();
        _viewModel.RankPathApplied += path => RankPathChanged?.Invoke(path);
        _viewModel.PidPathApplied += path => PidPathChanged?.Invoke(path);
        DataContext = _viewModel;
    }
    
    public delegate void PathChangedEventHandler(string path);

    public event PathChangedEventHandler? RankPathChanged;
    
    public event PathChangedEventHandler? PidPathChanged;
}
