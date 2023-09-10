using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using System.Net.Http;
using System.IO;
using System.Windows;
using Newtonsoft.Json;
using PixivTool.JsonHelper;

namespace PixivTool.ResourceHelper;

public class Downloader
{
        // private int maxRank = 1;
        private Dictionary<int, string> rankImageUrls = new Dictionary<int, string>();
        private static string cookie = string.Empty;

        private Dictionary<string, bool> RankOptions = new Dictionary<string, bool>();

        // private static Downloader _downloader;

        private static readonly Lazy<Downloader>
            InstanceDownloader = new Lazy<Downloader>(() => new Downloader(), true);

        private Downloader()
        {
            InitRankOptions();
            // maxRank = 1;
        }

        public static Downloader Instance => InstanceDownloader.Value;

        private void InitRankOptions()
        {
            RankOptions.Add("daily", false);
            RankOptions.Add("weekly", false);
            RankOptions.Add("monthly", false);

            RankOptions.Add("R18", false);

            RankOptions.Add("illust", false);
            RankOptions.Add("manga", false);
        }

        private string GetRankOptionsUrl()
        {
            string url = string.Empty;
            if (RankOptions["daily"])
            {
                if (RankOptions["R18"])
                {
                    url += "mode=daily_r18";
                }
                else
                {
                    url += "mode=daily";
                }
            }
            else if (RankOptions["weekly"])
            {
                if (RankOptions["R18"])
                {
                    url += "mode=weekly_r18";
                }
                else
                {
                    url += "mode=weekly";
                }
            }
            else if (RankOptions["monthly"])
            {
                if (RankOptions["R18"])
                {
                    url += "mode=monthly_r18";
                }
                else
                {
                    url += "mode=monthly";
                }
            }

            if (RankOptions["illust"])
            {
                if (url.EndsWith('&'))
                {
                    url += "content=illust";
                }
                else
                {
                    url += "&content=illust";
                }
            } 
            else if (RankOptions["manga"])
            {
                if (url.EndsWith('&'))
                {
                    url += "content=manga";
                }
                else
                {
                    url += "&content=manga";
                }
            }

            return url;
        }

        public void ModifyRankOptions(string type, bool flag)
        {
            RankOptions[type] = flag;
            // Console.WriteLine($"{type}:{flag}");
        }

        public static void SetCookie(string tCookie)
        {
            cookie = tCookie;
        }

        private static HttpClient CreateHttpClient()
        {
            HttpClient client = new HttpClient();
            client.DefaultRequestHeaders.Add("User-Agent",
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/116.0.0.0 Safari/537.36 Edg/116.0.1938.54");
            client.DefaultRequestHeaders.Add("Referer", "https://www.pixiv.net/");
            client.DefaultRequestHeaders.Add("Cookie", cookie);
            return client;
        }

        private async Task<List<string>> GetRankingPids(string rankBaseUrl = "https://www.pixiv.net/ranking.php?")
        {
            List<string> pids = new List<string>();
            using (HttpClient client = CreateHttpClient())
            {
                string rankDataUrl;
                string mode = GetRankOptionsUrl();
                for (int i = 1; i <= 10; i++)
                {
                    if (rankBaseUrl.EndsWith('&'))
                    {
                        rankDataUrl = $"{rankBaseUrl}{mode}p={i}&format=json";
                    }
                    else
                    {
                        rankDataUrl = $"{rankBaseUrl}{mode}&p={i}&format=json";
                    }

                    // Console.WriteLine(rankDataUrl);
                    HttpResponseMessage httpResponseMessage = await client.GetAsync(rankDataUrl);


                    if (httpResponseMessage.IsSuccessStatusCode)
                    {
                        string responseBody = await httpResponseMessage.Content.ReadAsStringAsync();

                        rankJsonObject.Root? jsonData =
                            JsonConvert.DeserializeObject<rankJsonObject.Root>(responseBody);
                        // Console.WriteLine(jsonData.contents.Count);
                        foreach (var imageContent in jsonData.contents)
                        {
                            // Console.WriteLine(imageContent.illust_id.ToString());
                            pids.Add(imageContent.illust_id.ToString());
                        }

                        if (jsonData.next.Equals("false"))
                        {
                            break;
                        }
                    }
                }
            }

            // Console.WriteLine(pids.Count);
            return pids;
        }

        public async Task GetRankImages(string path)
        {
            try
            {
                List<string> pids = await GetRankingPids();
                if (RankOptions["illust"])
                {
                    path += "illust/";
                }
                else if (RankOptions["manga"])
                {
                    path += "manga/";
                }
                if (RankOptions["R18"])
                {
                    path += "R18/";
                }
                foreach (var pid in pids)
                {
                    // Console.WriteLine("downloading...");
                    string url = await GetImageUrl(pid);
                    await DownloadImage(url, path);
                }
            }
            catch (Exception e)
            {
                Console.WriteLine(e);
                throw;
            }
        }

        public static async Task<string> GetImageUrl(string pid)
        {
            using (HttpClient client = CreateHttpClient())
            {
                string base_url = "https://www.pixiv.net/ajax/illust/";
                string url = $"{base_url}{pid}";
                HttpResponseMessage httpResponseMessage = await client.GetAsync(url);
                if (httpResponseMessage.IsSuccessStatusCode)
                {
                    string responseBody = await httpResponseMessage.Content.ReadAsStringAsync();
                    imageJsonObject.Root? jsonData = JsonConvert.DeserializeObject<imageJsonObject.Root>(responseBody);
                    if (jsonData.error)
                    {
                        MessageBox.Show("Invalid PID!");
                        return "https://i.pximg.net/img-original/img/2023/04/07/10/22/57/106942074_p0.jpg";
                    }
                    
                    if (jsonData.body != null)
                    {
                        return jsonData.body.urls.original;
                    }
                }
                else
                {
                    Console.WriteLine($"Request Failed: {httpResponseMessage.StatusCode}");
                    return string.Empty;
                }

                return string.Empty;
            }
        }

        public static async Task<Stream> GetPreviewImage(string pid)
        {
            using (HttpClient client = CreateHttpClient())
            {
                string base_url = "https://www.pixiv.net/ajax/illust/";
                string url = $"{base_url}{pid}";
                string previewImageUrl = "";
                HttpResponseMessage httpResponseMessage = await client.GetAsync(url);


                if (httpResponseMessage.IsSuccessStatusCode)
                {
                    string responseBody = await httpResponseMessage.Content.ReadAsStringAsync();
                    imageJsonObject.Root jsonData = JsonConvert.DeserializeObject<imageJsonObject.Root>(responseBody);
                    if (jsonData.error)
                    {
                        MessageBox.Show("Invalid PID!");
                        previewImageUrl = "https://i.pximg.net/c/250x250_80_a2/img-master/img/2023/04/07/10/22/57/106942074_p0_square1200.jpg";
                        // Console.WriteLine(previewImageUrl);
                        HttpResponseMessage previewMessage = await client.GetAsync(previewImageUrl);
                        if (previewMessage.IsSuccessStatusCode)
                        {
                            return await previewMessage.Content.ReadAsStreamAsync();
                        }
                    }
                    if (jsonData.body != null)
                    {
                        previewImageUrl = jsonData.body.urls.thumb;
                        // Console.WriteLine(previewImageUrl);
                        HttpResponseMessage previewMessage = await client.GetAsync(previewImageUrl);
                        if (previewMessage.IsSuccessStatusCode)
                        {
                            return await previewMessage.Content.ReadAsStreamAsync();
                        }
                    }
                }
                else
                {
                    Console.WriteLine($"Request Failed: {httpResponseMessage.StatusCode}");
                    MessageBox.Show("Invalid PID!");
                    previewImageUrl = "https://i.pximg.net/c/250x250_80_a2/img-master/img/2023/04/07/10/22/57/106942074_p0_square1200.jpg";
                    // Console.WriteLine(previewImageUrl);
                    HttpResponseMessage previewMessage = await client.GetAsync(previewImageUrl);
                    if (previewMessage.IsSuccessStatusCode)
                    {
                        return await previewMessage.Content.ReadAsStreamAsync();
                    }
                }

                return Stream.Null;
            }
        }

        private static string GetImageName(
            string imageUrl = "https://i.pximg.net/img-original/img/2023/04/07/10/22/57/106942074_p0.jpg")
        {
            string name = string.Empty;
            string[] items = imageUrl.Split('/');
            // Console.WriteLine(items.Length);
            name = items[items.Length - 1];
            // Console.WriteLine(name);
            return name;
        }

        public static async Task DownloadImage(
            string imageUrl = "https://i.pximg.net/img-original/img/2023/04/07/10/22/57/106942074_p0.jpg",
            string outputPath = "./test_image/")
        {
            using (HttpClient client = CreateHttpClient())
            {
                string name = GetImageName(imageUrl);
                if (!outputPath.EndsWith('/'))
                {
                    outputPath += '/';
                }

                HttpResponseMessage httpResponseMessage = await client.GetAsync(imageUrl);
                Directory.CreateDirectory(outputPath);
                string savePath = $"{outputPath}{name}";
                if (httpResponseMessage.IsSuccessStatusCode)
                {
                    using (Stream imageStream = await httpResponseMessage.Content.ReadAsStreamAsync())
                    {
                        using (FileStream fileStream = File.Create(savePath))
                        {
                            await imageStream.CopyToAsync(fileStream);
                        }
                    }
                }
            }
        }
    }