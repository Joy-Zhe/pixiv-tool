using System.Net;
using System.Text;
using PixivTool.Core.Models;
using PixivTool.Core.Services;

namespace PixivTool.Tests;

public sealed class PixivApiClientTests
{
    [Fact]
    public async Task GetRankingAsync_ShouldBuildExpectedQueryString()
    {
        var observedUris = new List<Uri>();
        var handler = new FakeHttpMessageHandler(request =>
        {
            observedUris.Add(request.RequestUri!);
            const string body = "{\"contents\":[{\"illust_id\":1001,\"title\":\"x\",\"rank\":1}],\"next\":\"false\"}";
            return Task.FromResult(new HttpResponseMessage(HttpStatusCode.OK)
            {
                Content = new StringContent(body, Encoding.UTF8, "application/json")
            });
        });

        using var httpClient = new HttpClient(handler);
        var client = new PixivApiClient(httpClient, () => "PHPSESSID=ok");

        var query = new RankingQuery
        {
            Mode = RankingMode.Weekly,
            Content = RankingContent.Illust,
            IsR18 = true,
            StartPage = 1,
            EndPage = 1
        };

        var result = await client.GetRankingAsync(query);

        Assert.Single(result);
        Assert.Single(observedUris);
        var first = observedUris[0].ToString();
        Assert.Contains("mode=weekly_r18", first);
        Assert.Contains("content=illust", first);
        Assert.Contains("p=1", first);
        Assert.Contains("format=json", first);
    }
}
