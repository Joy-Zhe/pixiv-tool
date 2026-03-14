using System.Text.Json;
using System.Text.Json.Serialization;
using PixivTool.Core.Abstractions;
using PixivTool.Core.Exceptions;
using PixivTool.Core.Models;

namespace PixivTool.Core.Services;

public sealed class PixivApiClient : IPixivApiClient
{
    private const string BrowserUserAgent =
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 " +
        "(KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36";

    private readonly HttpClient _httpClient;
    private readonly Func<string> _cookieProvider;

    public PixivApiClient(HttpClient httpClient, Func<string> cookieProvider)
    {
        _httpClient = httpClient;
        _cookieProvider = cookieProvider;
    }

    public async Task<IllustInfo> GetIllustByPidAsync(string pid, CancellationToken ct = default)
    {
        var payload = await GetIllustDetailAsync(pid, ct);

        return new IllustInfo
        {
            Pid = payload.Body.IllustId ?? pid,
            OriginalUrl = payload.Body.Urls.Original,
            ThumbUrl = payload.Body.Urls.Thumb ?? string.Empty,
            Title = payload.Body.Title ?? string.Empty
        };
    }

    public async Task<IReadOnlyList<string>> GetIllustPageUrlsAsync(string pid, CancellationToken ct = default)
    {
        ValidateCookie();

        try
        {
            using var request = CreateRequest(HttpMethod.Get, $"https://www.pixiv.net/ajax/illust/{pid}/pages");
            using var response = await _httpClient.SendAsync(request, ct);
            if (response.IsSuccessStatusCode)
            {
                await using var stream = await response.Content.ReadAsStreamAsync(ct);
                var payload = await JsonSerializer.DeserializeAsync<IllustPagesResponse>(stream, cancellationToken: ct);
                if (payload is not null && !payload.Error)
                {
                    var urls = payload.Body?
                        .Where(item => !string.IsNullOrWhiteSpace(item.Urls?.Original))
                        .Select(item => item.Urls!.Original!)
                        .ToList() ?? new List<string>();

                    if (urls.Count > 0)
                    {
                        return urls;
                    }
                }
            }
        }
        catch
        {
            // Fallback to illust detail below.
        }

        var detail = await GetIllustDetailAsync(pid, ct);
        var originalUrl = detail.Body.Urls.Original;
        var pageCount = detail.Body.PageCount <= 0 ? 1 : detail.Body.PageCount;

        if (pageCount <= 1 || string.IsNullOrWhiteSpace(originalUrl))
        {
            return new List<string> { originalUrl };
        }

        // Fallback pattern for multi-page illusts when /pages endpoint is blocked or empty.
        var urlsByPattern = new List<string>();
        for (var i = 0; i < pageCount; i++)
        {
            urlsByPattern.Add(originalUrl.Replace("_p0", $"_p{i}", StringComparison.Ordinal));
        }

        return urlsByPattern;
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
                if (page == query.StartPage)
                {
                    throw new PixivApiException(
                        $"Fetch ranking page {page} failed: {(int)response.StatusCode} {response.ReasonPhrase}");
                }

                // If later pages fail, keep already fetched data instead of failing the whole batch.
                break;
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

            if (IsNextFalse(payload.Next))
            {
                break;
            }
        }

        if (list.Count == 0)
        {
            throw new PixivApiException("Ranking list is empty. Cookie may be expired or blocked.");
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
        request.Headers.TryAddWithoutValidation("User-Agent", BrowserUserAgent);
        request.Headers.Referrer = new Uri("https://www.pixiv.net/");
        request.Headers.TryAddWithoutValidation("Accept",
            "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8");
        request.Headers.TryAddWithoutValidation("Accept-Language", "zh-CN,zh;q=0.9,en;q=0.8");
        request.Headers.TryAddWithoutValidation("Origin", "https://www.pixiv.net");
        request.Headers.TryAddWithoutValidation("Cookie", _cookieProvider());
        return request;
    }

    private async Task<IllustDetailResponse> GetIllustDetailAsync(string pid, CancellationToken ct)
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

        return payload;
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

        [JsonPropertyName("pageCount")]
        public int PageCount { get; set; }
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
        public JsonElement? Next { get; set; }
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

    private sealed class IllustPagesResponse
    {
        [JsonPropertyName("error")]
        public bool Error { get; set; }

        [JsonPropertyName("message")]
        public string? Message { get; set; }

        [JsonPropertyName("body")]
        public List<IllustPageBody>? Body { get; set; }
    }

    private sealed class IllustPageBody
    {
        [JsonPropertyName("urls")]
        public IllustUrls? Urls { get; set; }
    }

    private static bool IsNextFalse(JsonElement? next)
    {
        if (next is null)
        {
            return true;
        }

        var value = next.Value;
        return value.ValueKind switch
        {
            JsonValueKind.False => true,
            JsonValueKind.True => false,
            JsonValueKind.String => string.Equals(value.GetString(), "false", StringComparison.OrdinalIgnoreCase),
            JsonValueKind.Null => true,
            _ => false
        };
    }
}
