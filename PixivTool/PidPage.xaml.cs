using System.Windows.Controls;
using PixivTool.ViewModels;

namespace PixivTool;

public partial class PidPage : Page
{
    private readonly PidPageViewModel _viewModel;

    public PidPage()
    {
        InitializeComponent();
        _viewModel = new PidPageViewModel();
        DataContext = _viewModel;
    }

    public void SetPath(string path)
    {
        _viewModel.SetPath(path);
    }
}
