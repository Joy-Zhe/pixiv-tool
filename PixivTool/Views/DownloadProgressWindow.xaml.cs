using System.Windows;

namespace PixivTool.Views;

public partial class DownloadProgressWindow : Window
{
    public DownloadProgressWindow(string title)
    {
        InitializeComponent();
        TitleText.Text = title;
    }

    public void UpdateProgress(int completed, int total, string message)
    {
        if (total <= 0)
        {
            Progress.IsIndeterminate = true;
        }
        else
        {
            Progress.IsIndeterminate = false;
            Progress.Maximum = total;
            Progress.Value = completed;
        }

        StatusText.Text = message;
    }
}
