using System.Windows.Controls;
using PixivTool.ViewModels;

namespace PixivTool;

public partial class RankPage : Page
{
    private readonly RankPageViewModel _viewModel;

    public RankPage()
    {
        InitializeComponent();
        _viewModel = new RankPageViewModel();
        DataContext = _viewModel;
    }

    public void SetPath(string path)
    {
        _viewModel.SetPath(path);
    }
}
