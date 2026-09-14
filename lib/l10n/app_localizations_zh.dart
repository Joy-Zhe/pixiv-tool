// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'PixivTool';

  @override
  String get pid => 'PID 下载';

  @override
  String get ranking => '排行榜';

  @override
  String get bookmarks => '收藏夹';

  @override
  String get search => '搜索';

  @override
  String get searchKeyword => '标签或关键字';

  @override
  String get searchKeywordHint => '输入标签、标题或说明';

  @override
  String get searchMode => '搜索范围';

  @override
  String get searchTagPartial => '标签（部分匹配）';

  @override
  String get searchTagExact => '标签（完全匹配）';

  @override
  String get searchTitleDescription => '标题和说明';

  @override
  String get minLikes => '最低点赞数';

  @override
  String get minBookmarks => '最低收藏数';

  @override
  String get includeAiWorks => '包含 AI 作品';

  @override
  String get includeR18Works => '包含 R18 作品';

  @override
  String get searchAction => '搜索';

  @override
  String get stopSearch => '停止搜索';

  @override
  String get continueSearch => '继续查找';

  @override
  String searchProgress(Object pages, Object works) {
    return '已检查 $pages 页，扫描 $works 个作品';
  }

  @override
  String searchServerTotal(Object count) {
    return '筛选前结果数：$count';
  }

  @override
  String searchResultCount(Object count) {
    return '找到 $count 个匹配作品';
  }

  @override
  String searchDetailsFailed(Object count) {
    return '$count 个作品热度查询失败，重试';
  }

  @override
  String get noSearchResults => '暂无符合条件的作品';

  @override
  String get searchHint => '输入标签或关键字开始搜索';

  @override
  String get searchKeywordRequired => '请输入标签或关键字';

  @override
  String get sessionExpired => 'Pixiv 会话已过期，请重新登录';

  @override
  String get invalidPopularity => '请输入非负整数作为点赞数或收藏数';

  @override
  String get likeCountLabel => '点赞';

  @override
  String get bookmarkCountLabel => '收藏';

  @override
  String get downloads => '下载任务';

  @override
  String get settings => '设置';

  @override
  String get preview => '预览';

  @override
  String get download => '下载';

  @override
  String get downloadSelected => '下载所选';

  @override
  String get downloadFiltered => '下载全部筛选结果';

  @override
  String get refresh => '刷新';

  @override
  String get syncAll => '全量同步';

  @override
  String get publicBookmarks => '公开收藏';

  @override
  String get privateBookmarks => '非公开收藏';

  @override
  String get all => '全部';

  @override
  String get illust => '插画';

  @override
  String get manga => '漫画';

  @override
  String get ugoira => '动图';

  @override
  String get ugoiraUnsupported => '首版暂不支持动图下载';

  @override
  String get signIn => '登录 Pixiv';

  @override
  String get manualCookie => '手动 Cookie';

  @override
  String get save => '保存';

  @override
  String get logout => '退出登录';

  @override
  String get notSignedIn => '尚未登录';

  @override
  String get ready => '就绪';

  @override
  String get pauseAll => '全部暂停';

  @override
  String get resumeAll => '全部继续';

  @override
  String get retry => '重试';

  @override
  String get pause => '暂停';

  @override
  String get resume => '继续';

  @override
  String get cancel => '取消';

  @override
  String get remove => '移除';

  @override
  String get chooseFolder => '选择目录';

  @override
  String get language => '语言';

  @override
  String get theme => '主题';

  @override
  String get system => '跟随系统';

  @override
  String get light => '浅色';

  @override
  String get dark => '深色';

  @override
  String get proxy => '代理';

  @override
  String get direct => '直连';

  @override
  String get manual => '手动代理';

  @override
  String get concurrency => '并发下载数';

  @override
  String get pidFolder => 'PID 下载目录';

  @override
  String get rankingFolder => '排行榜目录';

  @override
  String get bookmarkFolder => '收藏夹目录';

  @override
  String selectedCount(Object count) {
    return '已选择 $count 项';
  }

  @override
  String get invalidPid => '请输入纯数字 PID';

  @override
  String get loading => '加载中…';

  @override
  String get noItems => '暂无内容';

  @override
  String operationFailed(Object message) {
    return '操作失败：$message';
  }

  @override
  String get settingsSaved => '设置已保存';

  @override
  String get account => '账户';

  @override
  String get cookieHint => '粘贴完整 Cookie 请求头';

  @override
  String get startPage => '起始页';

  @override
  String get endPage => '结束页';

  @override
  String get daily => '日榜';

  @override
  String get weekly => '周榜';

  @override
  String get monthly => '月榜';

  @override
  String get r18 => 'R18';

  @override
  String get filterTag => '收藏标签';

  @override
  String get clearSelection => '清空选择';

  @override
  String get selectLoaded => '选择已加载';

  @override
  String get openFolder => '打开目录';

  @override
  String get openFile => '打开文件';

  @override
  String queuedWorks(Object count) {
    return '已将 $count 个作品加入队列';
  }

  @override
  String get addedToQueue => '已加入下载队列';

  @override
  String get invalidPageRange => '请输入有效的页码范围';

  @override
  String get content => '内容类型';

  @override
  String get downloadSection => '下载';

  @override
  String get downloadFoldersRequired => '下载目录不能为空';

  @override
  String get validProxyRequired => '请输入有效的代理主机和端口';

  @override
  String get clearBookmarkCache => '清除收藏缓存';

  @override
  String get proxyHost => '主机';

  @override
  String get proxyPort => '端口';

  @override
  String get proxyUsername => '用户名';

  @override
  String get proxyPassword => '密码';

  @override
  String get simplifiedChinese => '简体中文';

  @override
  String get english => '英文';

  @override
  String tasksCount(Object count) {
    return '$count 个任务';
  }

  @override
  String get statusPending => '等待中';

  @override
  String get statusResolving => '正在解析';

  @override
  String get statusDownloading => '正在下载';

  @override
  String get statusPaused => '已暂停';

  @override
  String get statusWaitingForAuth => '等待重新登录';

  @override
  String get statusCompleted => '已完成';

  @override
  String get statusFailed => '失败';

  @override
  String get statusCancelled => '已取消';

  @override
  String get statusSkipped => '已跳过';

  @override
  String completedCount(Object count) {
    return '成功 $count';
  }

  @override
  String failedCount(Object count) {
    return '失败 $count';
  }

  @override
  String skippedCount(Object count) {
    return '跳过 $count';
  }

  @override
  String get removeTaskTitle => '移除下载任务？';

  @override
  String get removeTaskBody => '可以保留临时文件供稍后检查，也可以立即删除。';

  @override
  String get keepPartialFiles => '保留临时文件';

  @override
  String get deletePartialFiles => '删除临时文件';

  @override
  String get webLoginTitle => 'Pixiv 登录';

  @override
  String get useSession => '使用当前会话';

  @override
  String get sessionCookieMissing => '未找到 Pixiv 会话 Cookie，请先完成登录。';

  @override
  String syncSummary(Object received, Object removed) {
    return '已同步 $received 项，移除 $removed 项过期缓存';
  }

  @override
  String pagesCount(Object count) {
    return '$count 页';
  }

  @override
  String get webView2Missing =>
      '内嵌登录需要 Microsoft Edge WebView2 Runtime。请安装后重试，或在设置页使用手动 Cookie 登录。';

  @override
  String get ok => '确定';

  @override
  String get previewPage => '预览页码';

  @override
  String get previousPage => '上一页';

  @override
  String get nextPage => '下一页';

  @override
  String get downloadPageRange => '批量下载页码范围';

  @override
  String rankNumber(Object rank) {
    return '第 $rank 名';
  }
}
