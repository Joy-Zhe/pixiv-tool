using System.Collections.Generic;

namespace PixivTool.JsonHelper;

public class imageJsonObject
{
    public class Urls
    {
        public string? mini { get; set; }
        public string? thumb { get; set; }
        public string? small { get; set; }
        public string? regular { get; set; }
        public string? original { get; set; }
    }

    public class TagsItem
    {
        public string? tag { get; set; }
        public string? locked { get; set; }
        public string? deletable { get; set; }
        public string? userId { get; set; }
        public string? userName { get; set; }
    }

    public class Tags
    {
        public string? authorId { get; set; }
        public string? isLocked { get; set; }
        public List<TagsItem>? tags { get; set; }
        public string? writable { get; set; }
    }

    public class Body
    {
        public string? illustId { get; set; }
        public string? illustTitle { get; set; }
        public string? illustComment { get; set; }
        public string? id { get; set; }
        public string? title { get; set; }
        public string? description { get; set; }
        public int illustType { get; set; }
        public string? createDate { get; set; }
        public string? uploadDate { get; set; }
        public int restrict { get; set; }
        public int xRestrict { get; set; }
        public int sl { get; set; }
        public Urls urls { get; set; }
        public Tags tags { get; set; }
        public string? alt { get; set; }
        public string? userId { get; set; }
        public string? userName { get; set; }
        public string? userAccount { get; set; }
    }

    public class Root
    {
        public bool error { get; set; }
        public string? message { get; set; }
        public Body body { get; set; }
    }
}