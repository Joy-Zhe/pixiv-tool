using System.Windows.Controls;
using System;
using System.Windows;
using PixivTool.ResourceHelper;

namespace PixivTool;

public partial class RankPage : Page
{
    public RankPage()
    {
        InitializeComponent();
    }
    
    private string RankPath { get; set; }

    public void SetPath(string path)
    {
        RankPath = path;        
        Console.WriteLine(path);
    }

    public string GetRankPageBaseUrl()
    {
        if (DownloadOptions.SelectedIndex == 0)
        {
            
        }

        return string.Empty;
    }

    private async void RankDownload_OnClick(object sender, RoutedEventArgs e)
    {
        try
        {
            switch (DownloadOptions.SelectedIndex)
            {
                case 1:
                    Downloader.Instance.ModifyRankOptions("illust", true);
                    break;
                case 2:
                    Downloader.Instance.ModifyRankOptions("manga", true);
                    break;
                default:
                    break;
            }

            switch (TimeSpan.SelectedIndex)
            {
                case 0:
                    Downloader.Instance.ModifyRankOptions("daily", true);
                    break;
                case 1:
                    Downloader.Instance.ModifyRankOptions("weekly", true);
                    break;
                default:
                    break;
            }
            await Downloader.Instance.GetRankImages(RankPath);

        }
        catch (Exception exception)
        {
            Console.WriteLine(exception);
            throw;
        }
    }

    private void R18Selection_OnChecked(object sender, RoutedEventArgs e)
    {
        Downloader.Instance.ModifyRankOptions("R18", true);
        // Console.WriteLine("R18Set!");
    }

    private void R18Selection_OnUnchecked(object sender, RoutedEventArgs e)
    {
        Downloader.Instance.ModifyRankOptions("R18", false);
    }
}