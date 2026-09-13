import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'PixivTool'**
  String get appTitle;

  /// No description provided for @pid.
  ///
  /// In en, this message translates to:
  /// **'PID'**
  String get pid;

  /// No description provided for @ranking.
  ///
  /// In en, this message translates to:
  /// **'Ranking'**
  String get ranking;

  /// No description provided for @bookmarks.
  ///
  /// In en, this message translates to:
  /// **'Bookmarks'**
  String get bookmarks;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @searchKeyword.
  ///
  /// In en, this message translates to:
  /// **'Tag or keyword'**
  String get searchKeyword;

  /// No description provided for @searchKeywordHint.
  ///
  /// In en, this message translates to:
  /// **'Enter a tag, title, or description'**
  String get searchKeywordHint;

  /// No description provided for @searchMode.
  ///
  /// In en, this message translates to:
  /// **'Search scope'**
  String get searchMode;

  /// No description provided for @searchTagPartial.
  ///
  /// In en, this message translates to:
  /// **'Tag (partial match)'**
  String get searchTagPartial;

  /// No description provided for @searchTagExact.
  ///
  /// In en, this message translates to:
  /// **'Tag (exact match)'**
  String get searchTagExact;

  /// No description provided for @searchTitleDescription.
  ///
  /// In en, this message translates to:
  /// **'Title and description'**
  String get searchTitleDescription;

  /// No description provided for @minLikes.
  ///
  /// In en, this message translates to:
  /// **'Minimum likes'**
  String get minLikes;

  /// No description provided for @minBookmarks.
  ///
  /// In en, this message translates to:
  /// **'Minimum bookmarks'**
  String get minBookmarks;

  /// No description provided for @searchAction.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchAction;

  /// No description provided for @stopSearch.
  ///
  /// In en, this message translates to:
  /// **'Stop search'**
  String get stopSearch;

  /// No description provided for @continueSearch.
  ///
  /// In en, this message translates to:
  /// **'Continue searching'**
  String get continueSearch;

  /// No description provided for @searchProgress.
  ///
  /// In en, this message translates to:
  /// **'Checked {pages} page(s), scanned {works} works'**
  String searchProgress(Object pages, Object works);

  /// No description provided for @searchServerTotal.
  ///
  /// In en, this message translates to:
  /// **'Results before filtering: {count}'**
  String searchServerTotal(Object count);

  /// No description provided for @searchResultCount.
  ///
  /// In en, this message translates to:
  /// **'{count} matching work(s)'**
  String searchResultCount(Object count);

  /// No description provided for @searchDetailsFailed.
  ///
  /// In en, this message translates to:
  /// **'Popularity lookup failed for {count} work(s); retry'**
  String searchDetailsFailed(Object count);

  /// No description provided for @noSearchResults.
  ///
  /// In en, this message translates to:
  /// **'No matching works'**
  String get noSearchResults;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Enter a tag or keyword to search'**
  String get searchHint;

  /// No description provided for @searchKeywordRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a tag or keyword'**
  String get searchKeywordRequired;

  /// No description provided for @sessionExpired.
  ///
  /// In en, this message translates to:
  /// **'The Pixiv session has expired. Sign in again.'**
  String get sessionExpired;

  /// No description provided for @invalidPopularity.
  ///
  /// In en, this message translates to:
  /// **'Enter non-negative integers for likes or bookmarks'**
  String get invalidPopularity;

  /// No description provided for @likeCountLabel.
  ///
  /// In en, this message translates to:
  /// **'Likes'**
  String get likeCountLabel;

  /// No description provided for @bookmarkCountLabel.
  ///
  /// In en, this message translates to:
  /// **'Bookmarks'**
  String get bookmarkCountLabel;

  /// No description provided for @downloads.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get downloads;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @preview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get preview;

  /// No description provided for @download.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get download;

  /// No description provided for @downloadSelected.
  ///
  /// In en, this message translates to:
  /// **'Download selected'**
  String get downloadSelected;

  /// No description provided for @downloadFiltered.
  ///
  /// In en, this message translates to:
  /// **'Download all filtered'**
  String get downloadFiltered;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @syncAll.
  ///
  /// In en, this message translates to:
  /// **'Sync all'**
  String get syncAll;

  /// No description provided for @publicBookmarks.
  ///
  /// In en, this message translates to:
  /// **'Public'**
  String get publicBookmarks;

  /// No description provided for @privateBookmarks.
  ///
  /// In en, this message translates to:
  /// **'Private'**
  String get privateBookmarks;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @illust.
  ///
  /// In en, this message translates to:
  /// **'Illustration'**
  String get illust;

  /// No description provided for @manga.
  ///
  /// In en, this message translates to:
  /// **'Manga'**
  String get manga;

  /// No description provided for @ugoira.
  ///
  /// In en, this message translates to:
  /// **'Ugoira'**
  String get ugoira;

  /// No description provided for @ugoiraUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Ugoira download is not supported yet'**
  String get ugoiraUnsupported;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in to Pixiv'**
  String get signIn;

  /// No description provided for @manualCookie.
  ///
  /// In en, this message translates to:
  /// **'Manual Cookie'**
  String get manualCookie;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get logout;

  /// No description provided for @notSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Not signed in'**
  String get notSignedIn;

  /// No description provided for @ready.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get ready;

  /// No description provided for @pauseAll.
  ///
  /// In en, this message translates to:
  /// **'Pause all'**
  String get pauseAll;

  /// No description provided for @resumeAll.
  ///
  /// In en, this message translates to:
  /// **'Resume all'**
  String get resumeAll;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @resume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resume;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @chooseFolder.
  ///
  /// In en, this message translates to:
  /// **'Choose folder'**
  String get chooseFolder;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @system.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get system;

  /// No description provided for @light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get light;

  /// No description provided for @dark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get dark;

  /// No description provided for @proxy.
  ///
  /// In en, this message translates to:
  /// **'Proxy'**
  String get proxy;

  /// No description provided for @direct.
  ///
  /// In en, this message translates to:
  /// **'Direct'**
  String get direct;

  /// No description provided for @manual.
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get manual;

  /// No description provided for @concurrency.
  ///
  /// In en, this message translates to:
  /// **'Concurrent downloads'**
  String get concurrency;

  /// No description provided for @pidFolder.
  ///
  /// In en, this message translates to:
  /// **'PID folder'**
  String get pidFolder;

  /// No description provided for @rankingFolder.
  ///
  /// In en, this message translates to:
  /// **'Ranking folder'**
  String get rankingFolder;

  /// No description provided for @bookmarkFolder.
  ///
  /// In en, this message translates to:
  /// **'Bookmark folder'**
  String get bookmarkFolder;

  /// No description provided for @selectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String selectedCount(Object count);

  /// No description provided for @invalidPid.
  ///
  /// In en, this message translates to:
  /// **'Enter a numeric PID'**
  String get invalidPid;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get loading;

  /// No description provided for @noItems.
  ///
  /// In en, this message translates to:
  /// **'No items'**
  String get noItems;

  /// No description provided for @operationFailed.
  ///
  /// In en, this message translates to:
  /// **'Operation failed: {message}'**
  String operationFailed(Object message);

  /// No description provided for @settingsSaved.
  ///
  /// In en, this message translates to:
  /// **'Settings saved'**
  String get settingsSaved;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @cookieHint.
  ///
  /// In en, this message translates to:
  /// **'Paste the complete Cookie header'**
  String get cookieHint;

  /// No description provided for @startPage.
  ///
  /// In en, this message translates to:
  /// **'Start page'**
  String get startPage;

  /// No description provided for @endPage.
  ///
  /// In en, this message translates to:
  /// **'End page'**
  String get endPage;

  /// No description provided for @daily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get daily;

  /// No description provided for @weekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get weekly;

  /// No description provided for @monthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get monthly;

  /// No description provided for @r18.
  ///
  /// In en, this message translates to:
  /// **'R18'**
  String get r18;

  /// No description provided for @filterTag.
  ///
  /// In en, this message translates to:
  /// **'Bookmark tag'**
  String get filterTag;

  /// No description provided for @clearSelection.
  ///
  /// In en, this message translates to:
  /// **'Clear selection'**
  String get clearSelection;

  /// No description provided for @selectLoaded.
  ///
  /// In en, this message translates to:
  /// **'Select loaded'**
  String get selectLoaded;

  /// No description provided for @openFolder.
  ///
  /// In en, this message translates to:
  /// **'Open folder'**
  String get openFolder;

  /// No description provided for @openFile.
  ///
  /// In en, this message translates to:
  /// **'Open file'**
  String get openFile;

  /// No description provided for @queuedWorks.
  ///
  /// In en, this message translates to:
  /// **'Queued {count} works'**
  String queuedWorks(Object count);

  /// No description provided for @addedToQueue.
  ///
  /// In en, this message translates to:
  /// **'Added to download queue'**
  String get addedToQueue;

  /// No description provided for @invalidPageRange.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid page range'**
  String get invalidPageRange;

  /// No description provided for @content.
  ///
  /// In en, this message translates to:
  /// **'Content'**
  String get content;

  /// No description provided for @downloadSection.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get downloadSection;

  /// No description provided for @downloadFoldersRequired.
  ///
  /// In en, this message translates to:
  /// **'Download folders cannot be empty'**
  String get downloadFoldersRequired;

  /// No description provided for @validProxyRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid proxy host and port'**
  String get validProxyRequired;

  /// No description provided for @clearBookmarkCache.
  ///
  /// In en, this message translates to:
  /// **'Clear bookmark cache'**
  String get clearBookmarkCache;

  /// No description provided for @proxyHost.
  ///
  /// In en, this message translates to:
  /// **'Host'**
  String get proxyHost;

  /// No description provided for @proxyPort.
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get proxyPort;

  /// No description provided for @proxyUsername.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get proxyUsername;

  /// No description provided for @proxyPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get proxyPassword;

  /// No description provided for @simplifiedChinese.
  ///
  /// In en, this message translates to:
  /// **'Simplified Chinese'**
  String get simplifiedChinese;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @tasksCount.
  ///
  /// In en, this message translates to:
  /// **'{count} tasks'**
  String tasksCount(Object count);

  /// No description provided for @statusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get statusPending;

  /// No description provided for @statusResolving.
  ///
  /// In en, this message translates to:
  /// **'Resolving'**
  String get statusResolving;

  /// No description provided for @statusDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading'**
  String get statusDownloading;

  /// No description provided for @statusPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get statusPaused;

  /// No description provided for @statusWaitingForAuth.
  ///
  /// In en, this message translates to:
  /// **'Waiting for sign-in'**
  String get statusWaitingForAuth;

  /// No description provided for @statusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get statusCompleted;

  /// No description provided for @statusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get statusFailed;

  /// No description provided for @statusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get statusCancelled;

  /// No description provided for @statusSkipped.
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get statusSkipped;

  /// No description provided for @completedCount.
  ///
  /// In en, this message translates to:
  /// **'Completed {count}'**
  String completedCount(Object count);

  /// No description provided for @failedCount.
  ///
  /// In en, this message translates to:
  /// **'Failed {count}'**
  String failedCount(Object count);

  /// No description provided for @skippedCount.
  ///
  /// In en, this message translates to:
  /// **'Skipped {count}'**
  String skippedCount(Object count);

  /// No description provided for @removeTaskTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove download task?'**
  String get removeTaskTitle;

  /// No description provided for @removeTaskBody.
  ///
  /// In en, this message translates to:
  /// **'You can keep partial files for later inspection or delete them now.'**
  String get removeTaskBody;

  /// No description provided for @keepPartialFiles.
  ///
  /// In en, this message translates to:
  /// **'Keep partial files'**
  String get keepPartialFiles;

  /// No description provided for @deletePartialFiles.
  ///
  /// In en, this message translates to:
  /// **'Delete partial files'**
  String get deletePartialFiles;

  /// No description provided for @webLoginTitle.
  ///
  /// In en, this message translates to:
  /// **'Pixiv Login'**
  String get webLoginTitle;

  /// No description provided for @useSession.
  ///
  /// In en, this message translates to:
  /// **'Use session'**
  String get useSession;

  /// No description provided for @sessionCookieMissing.
  ///
  /// In en, this message translates to:
  /// **'Pixiv session cookie was not found. Complete login first.'**
  String get sessionCookieMissing;

  /// No description provided for @syncSummary.
  ///
  /// In en, this message translates to:
  /// **'Synced {received}; removed {removed} stale items'**
  String syncSummary(Object received, Object removed);

  /// No description provided for @pagesCount.
  ///
  /// In en, this message translates to:
  /// **'{count} page(s)'**
  String pagesCount(Object count);

  /// No description provided for @webView2Missing.
  ///
  /// In en, this message translates to:
  /// **'Microsoft Edge WebView2 Runtime is required for embedded login. Install it or use the manual Cookie login in Settings.'**
  String get webView2Missing;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @previewPage.
  ///
  /// In en, this message translates to:
  /// **'Preview page'**
  String get previewPage;

  /// No description provided for @previousPage.
  ///
  /// In en, this message translates to:
  /// **'Previous page'**
  String get previousPage;

  /// No description provided for @nextPage.
  ///
  /// In en, this message translates to:
  /// **'Next page'**
  String get nextPage;

  /// No description provided for @downloadPageRange.
  ///
  /// In en, this message translates to:
  /// **'Download page range'**
  String get downloadPageRange;

  /// No description provided for @rankNumber.
  ///
  /// In en, this message translates to:
  /// **'No. {rank}'**
  String rankNumber(Object rank);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
