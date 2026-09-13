// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'PixivTool';

  @override
  String get pid => 'PID';

  @override
  String get ranking => 'Ranking';

  @override
  String get bookmarks => 'Bookmarks';

  @override
  String get search => 'Search';

  @override
  String get searchKeyword => 'Tag or keyword';

  @override
  String get searchKeywordHint => 'Enter a tag, title, or description';

  @override
  String get searchMode => 'Search scope';

  @override
  String get searchTagPartial => 'Tag (partial match)';

  @override
  String get searchTagExact => 'Tag (exact match)';

  @override
  String get searchTitleDescription => 'Title and description';

  @override
  String get minLikes => 'Minimum likes';

  @override
  String get minBookmarks => 'Minimum bookmarks';

  @override
  String get searchAction => 'Search';

  @override
  String get stopSearch => 'Stop search';

  @override
  String get continueSearch => 'Continue searching';

  @override
  String searchProgress(Object pages, Object works) {
    return 'Checked $pages page(s), scanned $works works';
  }

  @override
  String searchServerTotal(Object count) {
    return 'Results before filtering: $count';
  }

  @override
  String searchResultCount(Object count) {
    return '$count matching work(s)';
  }

  @override
  String searchDetailsFailed(Object count) {
    return 'Popularity lookup failed for $count work(s); retry';
  }

  @override
  String get noSearchResults => 'No matching works';

  @override
  String get searchHint => 'Enter a tag or keyword to search';

  @override
  String get searchKeywordRequired => 'Enter a tag or keyword';

  @override
  String get sessionExpired => 'The Pixiv session has expired. Sign in again.';

  @override
  String get invalidPopularity =>
      'Enter non-negative integers for likes or bookmarks';

  @override
  String get likeCountLabel => 'Likes';

  @override
  String get bookmarkCountLabel => 'Bookmarks';

  @override
  String get downloads => 'Downloads';

  @override
  String get settings => 'Settings';

  @override
  String get preview => 'Preview';

  @override
  String get download => 'Download';

  @override
  String get downloadSelected => 'Download selected';

  @override
  String get downloadFiltered => 'Download all filtered';

  @override
  String get refresh => 'Refresh';

  @override
  String get syncAll => 'Sync all';

  @override
  String get publicBookmarks => 'Public';

  @override
  String get privateBookmarks => 'Private';

  @override
  String get all => 'All';

  @override
  String get illust => 'Illustration';

  @override
  String get manga => 'Manga';

  @override
  String get ugoira => 'Ugoira';

  @override
  String get ugoiraUnsupported => 'Ugoira download is not supported yet';

  @override
  String get signIn => 'Sign in to Pixiv';

  @override
  String get manualCookie => 'Manual Cookie';

  @override
  String get save => 'Save';

  @override
  String get logout => 'Sign out';

  @override
  String get notSignedIn => 'Not signed in';

  @override
  String get ready => 'Ready';

  @override
  String get pauseAll => 'Pause all';

  @override
  String get resumeAll => 'Resume all';

  @override
  String get retry => 'Retry';

  @override
  String get pause => 'Pause';

  @override
  String get resume => 'Resume';

  @override
  String get cancel => 'Cancel';

  @override
  String get remove => 'Remove';

  @override
  String get chooseFolder => 'Choose folder';

  @override
  String get language => 'Language';

  @override
  String get theme => 'Theme';

  @override
  String get system => 'System';

  @override
  String get light => 'Light';

  @override
  String get dark => 'Dark';

  @override
  String get proxy => 'Proxy';

  @override
  String get direct => 'Direct';

  @override
  String get manual => 'Manual';

  @override
  String get concurrency => 'Concurrent downloads';

  @override
  String get pidFolder => 'PID folder';

  @override
  String get rankingFolder => 'Ranking folder';

  @override
  String get bookmarkFolder => 'Bookmark folder';

  @override
  String selectedCount(Object count) {
    return '$count selected';
  }

  @override
  String get invalidPid => 'Enter a numeric PID';

  @override
  String get loading => 'Loading…';

  @override
  String get noItems => 'No items';

  @override
  String operationFailed(Object message) {
    return 'Operation failed: $message';
  }

  @override
  String get settingsSaved => 'Settings saved';

  @override
  String get account => 'Account';

  @override
  String get cookieHint => 'Paste the complete Cookie header';

  @override
  String get startPage => 'Start page';

  @override
  String get endPage => 'End page';

  @override
  String get daily => 'Daily';

  @override
  String get weekly => 'Weekly';

  @override
  String get monthly => 'Monthly';

  @override
  String get r18 => 'R18';

  @override
  String get filterTag => 'Bookmark tag';

  @override
  String get clearSelection => 'Clear selection';

  @override
  String get selectLoaded => 'Select loaded';

  @override
  String get openFolder => 'Open folder';

  @override
  String get openFile => 'Open file';

  @override
  String queuedWorks(Object count) {
    return 'Queued $count works';
  }

  @override
  String get addedToQueue => 'Added to download queue';

  @override
  String get invalidPageRange => 'Enter a valid page range';

  @override
  String get content => 'Content';

  @override
  String get downloadSection => 'Downloads';

  @override
  String get downloadFoldersRequired => 'Download folders cannot be empty';

  @override
  String get validProxyRequired => 'Enter a valid proxy host and port';

  @override
  String get clearBookmarkCache => 'Clear bookmark cache';

  @override
  String get proxyHost => 'Host';

  @override
  String get proxyPort => 'Port';

  @override
  String get proxyUsername => 'Username';

  @override
  String get proxyPassword => 'Password';

  @override
  String get simplifiedChinese => 'Simplified Chinese';

  @override
  String get english => 'English';

  @override
  String tasksCount(Object count) {
    return '$count tasks';
  }

  @override
  String get statusPending => 'Pending';

  @override
  String get statusResolving => 'Resolving';

  @override
  String get statusDownloading => 'Downloading';

  @override
  String get statusPaused => 'Paused';

  @override
  String get statusWaitingForAuth => 'Waiting for sign-in';

  @override
  String get statusCompleted => 'Completed';

  @override
  String get statusFailed => 'Failed';

  @override
  String get statusCancelled => 'Cancelled';

  @override
  String get statusSkipped => 'Skipped';

  @override
  String completedCount(Object count) {
    return 'Completed $count';
  }

  @override
  String failedCount(Object count) {
    return 'Failed $count';
  }

  @override
  String skippedCount(Object count) {
    return 'Skipped $count';
  }

  @override
  String get removeTaskTitle => 'Remove download task?';

  @override
  String get removeTaskBody =>
      'You can keep partial files for later inspection or delete them now.';

  @override
  String get keepPartialFiles => 'Keep partial files';

  @override
  String get deletePartialFiles => 'Delete partial files';

  @override
  String get webLoginTitle => 'Pixiv Login';

  @override
  String get useSession => 'Use session';

  @override
  String get sessionCookieMissing =>
      'Pixiv session cookie was not found. Complete login first.';

  @override
  String syncSummary(Object received, Object removed) {
    return 'Synced $received; removed $removed stale items';
  }

  @override
  String pagesCount(Object count) {
    return '$count page(s)';
  }

  @override
  String get webView2Missing =>
      'Microsoft Edge WebView2 Runtime is required for embedded login. Install it or use the manual Cookie login in Settings.';

  @override
  String get ok => 'OK';

  @override
  String get previewPage => 'Preview page';

  @override
  String get previousPage => 'Previous page';

  @override
  String get nextPage => 'Next page';

  @override
  String get downloadPageRange => 'Download page range';

  @override
  String rankNumber(Object rank) {
    return 'No. $rank';
  }
}
