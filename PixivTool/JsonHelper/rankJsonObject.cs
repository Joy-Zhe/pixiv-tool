using System.Collections.Generic;

namespace PixivTool.JsonHelper;

public class rankJsonObject
{
    public class Illust_content_type
    {
        public int sexual { get; set; }
        public string? lo { get; set; }
        public string? grotesque { get; set; }
        public string? violent { get; set; }
        public string? homosexual { get; set; }
        public string? drug { get; set; }
        public string? thoughts { get; set; }
        public string? antisocial { get; set; }
        public string? religion { get; set; }
        public string? original { get; set; }
        public string? furry { get; set; }
        public string? bl { get; set; }
        public string? yuri { get; set; }
    }

    public class ContentsItem
    {
        public string? title { get; set; }
        public string? date { get; set; }
        public List<string>? tags { get; set; }
        public string? url { get; set; }
        public string? illust_type { get; set; }
        public string? illust_book_style { get; set; }
        public string? illust_page_count { get; set; }
        public string? user_name { get; set; }
        public string? profile_img { get; set; }
        public Illust_content_type? illust_content_type { get; set; }
        // public string illust_series { get; set; } // wrong, fix it later
        public int illust_id { get; set; }
        public int width { get; set; }
        public int height { get; set; }
        public int user_id { get; set; }
        public int rank { get; set; }
        public int yes_rank { get; set; }
        public int rating_count { get; set; }
        public int view_count { get; set; }
        public int illust_upload_timestamp { get; set; }
        public string? attr { get; set; }
    }

    public class Root
    {
        public List<ContentsItem> contents { get; set; }
        public string? mode { get; set; }
        public string? content { get; set; }
        public int page { get; set; }
        public string? prev { get; set; }
        public string? next { get; set; }
        public string? date { get; set; }
        public string? prev_date { get; set; }
        public string? next_date { get; set; }
        public int rank_total { get; set; }
    }
}