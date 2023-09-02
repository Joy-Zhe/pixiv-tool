using System;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Xps.Serialization;
using System.Xml.Linq;
using pixivTool.ResourceHelper;
using System.IO;

namespace pixivTool;

public partial class SettingsPage : Page
{
    public delegate void PathChangedEventHandler(string path);

    public event PathChangedEventHandler RankPathChanged;
    
    public event PathChangedEventHandler PidPathChanged;
    public SettingsPage()
    {
        InitializeComponent();
        LoadData();
    }

    private void SaveData(string RankPath, string PidPath, string Cookie)
    {
        try
        {
            string data = $"{RankPath}\n{PidPath}\n{Cookie}";
            RankPathChanged?.Invoke(RankPath);
            PidPathChanged?.Invoke(PidPath);
            Downloader.SetCookie(Cookie);
            
            File.WriteAllText("settings.txt", data);

            MessageBox.Show("Settings Saved");
        }
        catch (Exception ex)
        {
            MessageBox.Show($"Failed:{ex.Message}");
        }
    }

    private void LoadData()
    {
        try
        {
            if (File.Exists("settings.txt"))
            {
                string[] lines = File.ReadAllLines("settings.txt");

                if (lines.Length >= 3)
                {
                    string RankPath = lines[0];
                    string PidPath = lines[1];
                    string Cookie = lines[2];

                    RankDownloadPath.Text = RankPath;
                    PidDownloadPath.Text = PidPath;
                    CookieRawMessage.Text = Cookie;
                    RankPathChanged?.Invoke(RankPath);
                    PidPathChanged?.Invoke(PidPath);
                    Downloader.SetCookie(Cookie);
                }
            }
        }
        catch (Exception ex)
        {
            MessageBox.Show($"Reading error:{ex.Message}");
        }
    }

    private void RankPathBtn_OnClick(object sender, RoutedEventArgs e)
    {
        try
        {
            string path = RankDownloadPath.Text;
            RankPathChanged?.Invoke(path);
        }
        catch (Exception exception)
        {
            Console.WriteLine(exception);
            throw;
        }
    }

    private void PidPathBtn_OnClick(object sender, RoutedEventArgs e)
    {
        try
        {
            string path = PidDownloadPath.Text;
            PidPathChanged?.Invoke(path);
        }
        catch (Exception exception)
        {
            Console.WriteLine(exception);
            throw;
        }
    }

    private void CookieSetBtn_OnClick(object sender, RoutedEventArgs e)
    {
        try
        {
            Downloader.SetCookie(CookieRawMessage.Text);
            SaveData(RankDownloadPath.Text, PidDownloadPath.Text, CookieRawMessage.Text);
        }
        catch (Exception exception)
        {
            Console.WriteLine(exception);
            throw;
        }
    }
}