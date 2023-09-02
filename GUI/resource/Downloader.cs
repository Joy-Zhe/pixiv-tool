using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using System.Net.Http;
using System.IO;
using System.Reflection.Emit;
using System.Text.Json.Serialization;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using GUI.jsonHelper;

namespace GUI.resource
{
    class Downloader
    {
        private int maxRank = 1;
        private Dictionary<int, string> rankImageUrls = new Dictionary<int, string>();

        private static HttpClient CreateHttpClient()
        {
            HttpClient client = new HttpClient();
            client.DefaultRequestHeaders.Add("User-Agent",
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/116.0.0.0 Safari/537.36 Edg/116.0.1938.54");
            client.DefaultRequestHeaders.Add("Referer", "https://www.pixiv.net/");
            return client;
        }
        
        private static async Task GetRankingJson()
        {
            using (HttpClient client = CreateHttpClient())
            {
                for (int i = 0; i < 10; i++)
                {
                    string rankDataUrl = $"https://www.pixiv.net/ranking.php?p={i}&format=json";
                    HttpResponseMessage httpResponseMessage = await client.GetAsync(rankDataUrl);
                    List<string> pids = new List<string>();
                    
                }
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
                    imageJsonObject.Root jsonData = JsonConvert.DeserializeObject<imageJsonObject.Root>(responseBody);
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

        public static async Task DownloadImage(string imageUrl, string outputPath="../test_image/")
        {
            using (HttpClient client = CreateHttpClient())
            {
                HttpResponseMessage httpResponseMessage = await client.GetAsync(imageUrl);
                Directory.CreateDirectory(outputPath);
                string savePath = $"{outputPath}test.jpg";
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
}