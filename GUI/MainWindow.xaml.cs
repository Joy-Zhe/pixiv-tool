using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Data;
using System.Windows.Documents;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Navigation;
using System.Windows.Shapes;
using GUI.resource;

namespace GUI
{
    /// <summary>
    /// Interaction logic for MainWindow.xaml
    /// </summary>
    public partial class MainWindow : Window
    {
        int Download_option = 0; // default = all {0: all, 1: pic, 2: comic}
        public MainWindow()
        {
            InitializeComponent();
        }

        private void DownloadOptions_SelectionChanged(object sender, SelectionChangedEventArgs e)
        {
            if (DownloadOptions.SelectedIndex == 0)
            {
                Download_option = 0;
            } 
            else if (DownloadOptions.SelectedIndex == 1)
            {
                Download_option = 1;
            }
            else if (DownloadOptions.SelectedIndex == 2)
            {
                Download_option = 2;
            }
        }

        private async void RankDownloadBtn_Click(object sender, RoutedEventArgs e)
        {
            string contents = await Downloader.GetImageUrl("106942074");
            testLabel.Content = contents;
            await Downloader.DownloadImage(contents);
            Console.WriteLine(contents);
        }

        private void PIDtext_TextChanged(object sender, TextChangedEventArgs e)
        {

        }

        private void pidDownloadBtn_Click(object sender, RoutedEventArgs e)
        {
           
        }
    }
}
