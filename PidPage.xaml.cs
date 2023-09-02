using pixivTool.ResourceHelper;
using System;
using System.Net.Http;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media.Imaging;
using System.IO;
using System.Threading.Tasks;

namespace pixivTool;

public partial class PidPage : Page
{
    private string PidPath { get; set; }

    public PidPage()
    {
        InitializeComponent();
    }

    public void SetPath(string path)
    {
        PidPath = path;
        Console.WriteLine(path);
    }

    private async void PidPreviewBtn_OnClick(object sender, RoutedEventArgs e)
    {
        try
        {
            string pid = PidContent.Text;
            Stream imageStream = await Downloader.GetPreviewImage(pid);
            
            BitmapImage bitmapImage = new BitmapImage();
            bitmapImage.BeginInit();
            bitmapImage.CacheOption = BitmapCacheOption.OnLoad;
            bitmapImage.StreamSource = imageStream;
            bitmapImage.EndInit();
            
            PreviewWindow.Source = bitmapImage;
        }
        catch (Exception exception)
        {
            Console.WriteLine(exception);
            throw;
        }
    }

    private async void PidDownloadBtn_OnClick(object sender, RoutedEventArgs e)
    {
        try
        {
            string pid = PidContent.Text;
            string content = await Downloader.GetImageUrl(pid);
            await Downloader.DownloadImage(content, PidPath);
        }
        catch (Exception exception)
        {
            Console.WriteLine(exception);
            throw;
        }
    }
}