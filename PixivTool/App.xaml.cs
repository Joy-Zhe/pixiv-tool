using System;
using System.IO;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Threading;

namespace PixivTool
{
    /// <summary>
    /// Interaction logic for App.xaml
    /// </summary>
    public partial class App : Application
    {
        public App()
        {
            DispatcherUnhandledException += OnDispatcherUnhandledException;
            AppDomain.CurrentDomain.UnhandledException += OnCurrentDomainUnhandledException;
            TaskScheduler.UnobservedTaskException += OnUnobservedTaskException;
        }

        private void OnDispatcherUnhandledException(object sender, DispatcherUnhandledExceptionEventArgs e)
        {
            WriteCrashLog("DispatcherUnhandledException", e.Exception);
            MessageBox.Show($"Unexpected error: {e.Exception.Message}\n\nDetails saved to crash.log");
            e.Handled = true;
        }

        private void OnCurrentDomainUnhandledException(object sender, UnhandledExceptionEventArgs e)
        {
            WriteCrashLog("AppDomainUnhandledException", e.ExceptionObject as Exception);
        }

        private void OnUnobservedTaskException(object? sender, UnobservedTaskExceptionEventArgs e)
        {
            WriteCrashLog("UnobservedTaskException", e.Exception);
            e.SetObserved();
        }

        private static void WriteCrashLog(string source, Exception? ex)
        {
            try
            {
                var content =
                    $"[{DateTime.Now:yyyy-MM-dd HH:mm:ss}] {source}{Environment.NewLine}" +
                    $"{ex}{Environment.NewLine}{Environment.NewLine}";
                File.AppendAllText("crash.log", content);
            }
            catch
            {
                // ignored
            }
        }
    }
}
