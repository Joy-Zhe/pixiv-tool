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

namespace PixivTool
{
    /// <summary>
    /// Interaction logic for MainWindow.xaml
    /// </summary>
    public partial class MainWindow : Window
    {
        public MainWindow()
        {
            InitializeComponent();
            SettingsPage settingsPage;
            if (BufferPages.ContainsKey("Settings"))
            {
                settingsPage = (SettingsPage)BufferPages["Settings"];
            }
            else
            {
                settingsPage = new SettingsPage();
                BufferPages.Add("Settings", settingsPage);
            }
            // Event Connected
            settingsPage.RankPathChanged += SetRankPath;
            settingsPage.PidPathChanged += SetPidPath;
        }
        
        private static readonly Dictionary<string, Page> BufferPages = new Dictionary<string, Page>();
        private string RankDownloadPath = "./rank/";
        private string PidDownloadPath = "./pids/";

        private void SetRankPath(string path)
        {
            RankDownloadPath = path;
        }

        public void SetPidPath(string path)
        {
            PidDownloadPath = path;
        }

        private void Rank_OnClick(object sender, RoutedEventArgs e)
        {
            try
            {
                RankPage page = new RankPage();
                if(!BufferPages.ContainsKey("Rank"))
                {
                    page = new RankPage();
                    page.SetPath(RankDownloadPath);
                    BufferPages.Add("Rank", page);
                }
                else
                {
                    page = (RankPage)BufferPages["Rank"];
                }
                currentFrame.Navigate(page);
            }
            catch (Exception exception)
            {
                Console.WriteLine(exception);
                throw;
            }
        }

        private void Pid_OnClick(object sender, RoutedEventArgs e)
        {
            try
            {
                // Console.WriteLine(RankDownloadPath);
                PidPage page = new PidPage();
                if(!BufferPages.ContainsKey("Pid"))
                {
                    page = new PidPage();
                    page.SetPath(PidDownloadPath);
                    BufferPages.Add("Pid", page);
                }
                else
                {
                    page = (PidPage)BufferPages["Pid"];
                }
                currentFrame.Navigate(page);
            }
            catch (Exception exception)
            {
                Console.WriteLine(exception);
                throw;
            }
        }

        private void Settings_OnClick(object sender, RoutedEventArgs e)
        {
            try
            {
                Page page = new Page();
                if(!BufferPages.ContainsKey("Settings"))
                {
                    page = new SettingsPage();
                    BufferPages.Add("Settings", page);
                }
                else
                {
                    page = BufferPages["Settings"];
                }
                currentFrame.Navigate(page);
            }
            catch (Exception exception)
            {
                Console.WriteLine(exception);
                throw;
            }
        }

        private void Star_OnClick(object sender, RoutedEventArgs e)
        {
            try
            {
                Page page = new StarPage();
                if(!BufferPages.ContainsKey("Star"))
                {
                    page = new StarPage();
                    BufferPages.Add("Star", page);
                }
                else
                {
                    page = BufferPages["Star"];
                }
                currentFrame.Navigate(page);
            }
            catch (Exception exception)
            {
                Console.WriteLine(exception);
                throw;
            }
        }
    }
}