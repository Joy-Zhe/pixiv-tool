using System.Net.Http.Headers;
using System.Text.Json;
using System.Text.Json.Serialization;
using PixivTool.Core.Abstractions;
using PixivTool.Core.Exceptions;
using PixivTool.Core.Models;

namespace PixivTool.Core.Services;

public sealed class PixivApiClient : IPixivApiClient
{
    private readonly HttpClient _httpClient;
    private readonly Func<string> _cookieProvider;

    public PixivApiClient(HttpClient httpClient, Func<string> cookieProvider)
    {
        _httpClient = httpClient;
        _cookieProvider = cookieProvider;
    }

    public async Task<IllustInfo> GetIllustByPidAsync(string pid, CancellationToken ct = default)
    {
        ValidateCookie();

        using var request = CreateRequest(HttpMethod.Get, $"https://www.pixiv.net/ajax/illust/{pid}");
        using var response = await _httpClient.SendAsync(request, ct);
        if (!response.IsSuccessStatusCode)
        {
            throw new PixivApiException($"Fetch illust failed: {(int)response.StatusCode} {response.ReasonPhrase}");
        }

        await using var stream = await response.Content.ReadAsStreamAsync(ct);
        var payload = await JsonSerializer.DeserializeAsync<IllustDetailResponse>(stream, cancellationToken: ct);
        if (payload is null)
        {
            throw new PixivApiException("Pixiv response is empty.");
        }

        if (payload.Error)
        {
            throw new PixivApiException($"Pixiv rejected pid {pid}: {payload.Message ?? "unknown error"}");
        }

        if (payload.Body?.Urls?.Original is null)
        {
            throw new PixivApiException($"Pixiv response missing original URL for pid {pid}.");
        }

        return new IllustInfo
        {
            Pid = payload.Body.IllustId ?? pid,
            OriginalUrl = payload.Body.Urls.Original,
            ThumbUrl = payload.Body.Urls.Thumb ?? string.Empty,
            Title = payload.Body.Title ?? string.Empty
        };
    }

    public async Task<IReadOnlyList<RankingItem>> GetRankingAsync(RankingQuery query, CancellationToken ct = default)
    {
        ValidateCookie();
        var list = new List<RankingItem>();

        for (var page = query.StartPage; page <= query.EndPage; page++)
        {
            var url = $"https://www.pixiv.net/ranking.php?{BuildRankingQueryString(query)}&p={page}&format=json";
            using var request = CreateRequest(HttpMethod.Get, url);
            using var response = await _httpClient.SendAsync(request, ct);

            if (!response.IsSuccessStatusCode)
            {
                throw new PixivApiException($"Fetch ranking page {page} failed: {(int)response.StatusCode} {response.ReasonPhrase}");
            }

            await using var stream = await response.Content.ReadAsStreamAsync(ct);
            var payload = await JsonSerializer.DeserializeAsync<RankingResponse>(stream, cancellationToken: ct);
            if (payload?.Contents is null)
            {
                continue;
            }

            list.AddRange(payload.Contents.Select(item => new RankingItem
            {
                Pid = item.IllustId.ToString(),
                Rank = item.Rank,
                Title = item.Title ?? string.Empty
            }));

            if (string.Equals(payload.Next, "false", StringComparison.OrdinalIgnoreCase))
            {
                break;
            }
        }

        return list;
    }

    public async Task<Stream> GetPreviewImageAsync(string pid, CancellationToken ct = default)
    {
        var info = await GetIllustByPidAsync(pid, ct);
        var previewUrl = string.IsNullOrWhiteSpace(info.ThumbUrl) ? info.OriginalUrl : info.ThumbUrl;

        using var request = CreateRequest(HttpMethod.Get, previewUrl);
        using var response = await _httpClient.SendAsync(request, ct);
        if (!response.IsSuccessStatusCode)
        {
            throw new PixivApiException($"Fetch preview failed: {(int)response.StatusCode} {response.ReasonPhrase}");
        }

        var memory = new MemoryStream();
        await using var stream = await response.Content.ReadAsStreamAsync(ct);
        await stream.CopyToAsync(memory, ct);
        memory.Position = 0;
        return memory;
    }

    private static string BuildRankingQueryString(RankingQuery query)
    {
        var mode = query.Mode switch
        {
            RankingMode.Daily => query.IsR18 ? "daily_r18" : "daily",
            RankingMode.Weekly => query.IsR18 ? "weekly_r18" : "weekly",
            RankingMode.Monthly => query.IsR18 ? "monthly_r18" : "monthly",
            _ => "daily"
        };

        var content = query.Content switch
        {
            RankingContent.Illust => "illust",
            RankingContent.Manga => "manga",
            _ => string.Empty
        };

        return string.IsNullOrWhiteSpace(content)
            ? $"mode={mode}"
            : $"mode={mode}&content={content}";
    }

    private HttpRequestMessage CreateRequest(HttpMethod method, string url)
    {
        var request = new HttpRequestMessage(method, url);
        request.Headers.UserAgent.Add(new ProductInfoHeaderValue("PixivTool", "1.0"));
        request.Headers.Referrer = new Uri("https://www.pixiv.net/");
        request.Headers.TryAddWithoutValidation("Cookie", _cookieProvider());
        return request;
    }

    private void ValidateCookie()
    {
        if (string.IsNullOrWhiteSpace(_cookieProvider()))
        {
            throw new PixivAuthException("Cookie is not configured.");
        }
    }

    private sealed class IllustDetailResponse
    {
        [JsonPropertyName("error")]
        public bool Error { get; set; }

        [JsonPropertyName("message")]
        public string? Message { get; set; }

        [JsonPropertyName("body")]
        public IllustBody? Body { get; set; }
    }

    private sealed class IllustBody
    {
        [JsonPropertyName("illustId")]
        public string? IllustId { get; set; }

        [JsonPropertyName("title")]
        public string? Title { get; set; }

        [JsonPropertyName("urls")]
        public IllustUrls? Urls { get; set; }
    }

    private sealed class IllustUrls
    {
        [JsonPropertyName("thumb")]
        public string? Thumb { get; set; }

        [JsonPropertyName("original")]
        public string? Original { get; set; }
    }

    private sealed class RankingResponse
    {
        [JsonPropertyName("contents")]
        public List<RankingContentItem>? Contents { get; set; }

        [JsonPropertyName("next")]
        public string? Next { get; set; }
    }

    private sealed class RankingContentItem
    {
        [JsonPropertyName("illust_id")]
        public int IllustId { get; set; }

        [JsonPropertyName("title")]
        public string? Title { get; set; }

        [JsonPropertyName("rank")]
        public int Rank { get; set; }
    }
}
