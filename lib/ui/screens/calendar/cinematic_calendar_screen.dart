import 'dart:async';

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:moonfin_design/moonfin_design.dart';
import 'package:server_core/server_core.dart';

import '../../../data/repositories/seerr_repository.dart';
import '../../../data/utils/blocked_ratings.dart';
import '../../../data/services/calendar_source_loader.dart';
import '../../../data/services/calendar_refresh_loop.dart';
import '../../navigation/route_lifecycle_observer.dart';
import '../../../util/calendar_eastern_time.dart';
import '../../../data/services/plugin_sync_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../../preference/user_preferences.dart';
import '../../navigation/destinations.dart';
import '../../widgets/bounded_network_image.dart';
import '../../widgets/navigation_layout.dart';
import '../../widgets/focus/focusable_wrapper.dart';

enum CalendarMediaFilter { all, tv, movies }

List<CinematicCalendarEntry> filterCalendarEntries(
  List<CinematicCalendarEntry> entries,
  CalendarMediaFilter filter,
) => entries
    .where(
      (entry) =>
          filter == CalendarMediaFilter.all ||
          (filter == CalendarMediaFilter.tv ? entry.isTv : !entry.isTv),
    )
    .toList();

class CinematicCalendarEntry {
  const CinematicCalendarEntry({
    required this.date,
    required this.title,
    required this.subtitle,
    required this.route,
    this.imageUrl,
    this.hasAirTime = false,
    this.episodeKey,
    this.timingPriority = 0,
    this.isTv = false,
    this.availabilityLabel,
  });
  final DateTime date;
  final String title;
  final String subtitle;
  final String route;
  final String? imageUrl;
  final bool hasAirTime;
  final String? episodeKey;
  final int timingPriority;
  final bool isTv;
  final String? availabilityLabel;
}

String calendarEntryIdentity(CinematicCalendarEntry entry) =>
    entry.episodeKey ??
    '${entry.isTv}|${entry.title}|${entry.date.toIso8601String()}|${entry.subtitle}';

String? calendarEpisodeKey(String? series, Object? season, Object? episode) {
  final name = series?.toLowerCase().replaceAll(
    RegExp(r'[^\p{L}\p{N}]', unicode: true),
    '',
  );
  if (name == null || name.isEmpty || season == null || episode == null)
    return null;
  return '$name|$season|$episode';
}

String? calendarLocalItemId(Map item) {
  final id = item['moonfinItemId']?.toString().trim();
  return id == null || id.isEmpty ? null : id;
}

String? calendarAvailabilityLabel(Map item, {required bool tv}) {
  if (tv) {
    final episode = item['moonfinEpisodeId']?.toString().trim();
    if (episode != null && episode.isNotEmpty) return 'Available';
    return calendarLocalItemId(item) == null ? null : 'Series available';
  }
  return calendarLocalItemId(item) == null ? null : 'Available';
}

String sonarrCalendarRoute(Map item) {
  for (final key in ['moonfinEpisodeId', 'moonfinItemId']) {
    final localId = item[key]?.toString().trim();
    if (localId != null && localId.isNotEmpty)
      return Destinations.item(localId);
  }
  final series = item['series'] as Map?;
  final tmdb = series?['tmdbId']?.toString();
  if (tmdb != null && tmdb.isNotEmpty && tmdb != '0') {
    return Destinations.seerrMedia(tmdb, mediaType: 'tv');
  }
  // Sonarr commonly identifies a show by TVDB alone. Keep its airing visible
  // and open title search rather than discarding an otherwise valid timestamp.
  return Destinations.searchWith('${series?['title'] ?? item['title'] ?? ''}');
}

({DateTime date, bool hasTime})? sonarrCalendarDate(Map item) {
  final utc = '${item['airDateUtc'] ?? ''}'.trim();
  final parsed = DateTime.tryParse(utc);
  // An explicit UTC/offset timestamp is authoritative. Never treat a date-only
  // field, or a timestamp without a timezone, as a known viewer-local air time.
  if (parsed != null &&
      RegExp(
        r'T\d{2}:\d{2}.*(?:Z|[+-]\d{2}:?\d{2})$',
        caseSensitive: false,
      ).hasMatch(utc)) {
    return (date: parsed, hasTime: true);
  }
  final day = DateTime.tryParse('${item['airDate'] ?? ''}');
  return day == null
      ? null
      : (date: DateTime(day.year, day.month, day.day), hasTime: false);
}

/// Timed entries are grouped by Eastern days, regardless of the device zone.
List<CinematicCalendarEntry> calendarEntriesForMonth(
  Iterable<CinematicCalendarEntry> entries,
  DateTime month,
) => calendarEntriesForRange(
  entries,
  DateTime(month.year, month.month),
  DateTime(month.year, month.month + 1),
);

List<CinematicCalendarEntry> calendarEntriesForRange(
  Iterable<CinematicCalendarEntry> entries,
  DateTime start,
  DateTime end,
) {
  final selected = <String, CinematicCalendarEntry>{};
  for (final entry in entries) {
    final local = calendarEasternDate(entry.date, hasAirTime: entry.hasAirTime);
    final key =
        entry.episodeKey ??
        '${entry.route}|${local.toIso8601String()}|${entry.subtitle}';
    final prior = selected[key];
    if (prior == null ||
        entry.timingPriority > prior.timingPriority ||
        (entry.hasAirTime && !prior.hasAirTime)) {
      // Prefer the local playback route/artwork while replacing its date-only
      // premiere with the trusted Sonarr airing timestamp and episode details.
      selected[key] = prior == null
          ? entry
          : CinematicCalendarEntry(
              date: entry.date,
              title: entry.title,
              subtitle: entry.subtitle,
              route: calendarPreferredRoute(prior, entry),
              imageUrl: entry.imageUrl ?? prior.imageUrl,
              hasAirTime: entry.hasAirTime,
              episodeKey: key,
              timingPriority: entry.timingPriority,
              isTv: entry.isTv,
              availabilityLabel: calendarPreferredAvailability(prior, entry),
            );
    } else if (calendarPreferredRoute(prior, entry) != prior.route) {
      selected[key] = CinematicCalendarEntry(
        date: prior.date,
        title: prior.title,
        subtitle: prior.subtitle,
        route: entry.route,
        imageUrl: prior.imageUrl ?? entry.imageUrl,
        hasAirTime: prior.hasAirTime,
        episodeKey: key,
        timingPriority: prior.timingPriority,
        isTv: prior.isTv,
        availabilityLabel: calendarPreferredAvailability(prior, entry),
      );
    }
  }
  return selected.values.where((entry) {
    final local = calendarEasternDate(entry.date, hasAirTime: entry.hasAirTime);
    final day = DateTime(local.year, local.month, local.day);
    return !day.isBefore(start) && day.isBefore(end);
  }).toList()..sort((a, b) {
    final left = calendarEasternDate(a.date, hasAirTime: a.hasAirTime);
    final right = calendarEasternDate(b.date, hasAirTime: b.hasAirTime);
    final order =
        DateTime.utc(
          left.year,
          left.month,
          left.day,
          left.hour,
          left.minute,
        ).compareTo(
          DateTime.utc(
            right.year,
            right.month,
            right.day,
            right.hour,
            right.minute,
          ),
        );
    return order != 0 ? order : a.date.compareTo(b.date);
  });
}

String? calendarPreferredAvailability(
  CinematicCalendarEntry a,
  CinematicCalendarEntry b,
) => a.availabilityLabel == 'Available' || b.availabilityLabel == 'Available'
    ? 'Available'
    : b.availabilityLabel ?? a.availabilityLabel;
String calendarPreferredRoute(
  CinematicCalendarEntry a,
  CinematicCalendarEntry b,
) {
  if (b.route.startsWith('/item/') &&
      (!a.route.startsWith('/item/') || b.availabilityLabel == 'Available'))
    return b.route;
  return a.route.startsWith('/item/') ? a.route : b.route;
}

class CinematicCalendarScreen extends StatefulWidget {
  const CinematicCalendarScreen({super.key});
  @override
  State<CinematicCalendarScreen> createState() =>
      _CinematicCalendarScreenState();
}

class _CinematicCalendarScreenState extends State<CinematicCalendarScreen>
    with WidgetsBindingObserver, RouteAware {
  late final CalendarRefreshLoop _refreshLoop;
  bool _foreground = true, _routeVisible = true;
  ModalRoute<dynamic>? _observedRoute;
  final _sourceRows = <String, List<CinematicCalendarEntry>>{};
  void _updateActivity({bool refresh = false}) =>
      _refreshLoop.setActive(_foreground && _routeVisible, refresh: refresh);
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null && route != _observedRoute) {
      if (_observedRoute != null) routeLifecycleObserver.unsubscribe(this);
      _observedRoute = route;
      routeLifecycleObserver.subscribe(this, route);
    }
  }

  @override
  void didPushNext() {
    _routeVisible = false;
    _updateActivity();
  }

  @override
  void didPopNext() {
    _routeVisible = true;
    _updateActivity(refresh: true);
  }

  final _entryFocus = <String, FocusNode>{};
  Future<void> _openEntry(CinematicCalendarEntry entry, FocusNode node) async {
    await context.push(entry.route);
    if (!mounted) return;
    if (node.context != null) node.requestFocus();
  }

  DateTime _month = DateTime(
    calendarEasternNow().year,
    calendarEasternNow().month,
    calendarEasternNow().day,
  );
  List<CinematicCalendarEntry> _entries = [];
  CalendarMediaFilter _mediaFilter = CalendarMediaFilter.all;
  bool _loading = true;
  bool _refreshing = false;
  StreamSubscription<CalendarSourceSnapshot<CinematicCalendarEntry>>?
  _calendarSubscription;
  bool _partialFailure = false;
  final Map<String, String> _sourceFailures = {};
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshLoop = CalendarRefreshLoop(
      read: () => unawaited(_load()),
      busy: () => _refreshing,
    );
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _updateActivity();
    _watchedPrefs.addListener(_onConfigurationChanged);
    _watchedSync?.addListener(_onConfigurationChanged);
    if (_foreground) unawaited(_load());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _updateActivity(refresh: _foreground);
  }

  late final _watchedPrefs = GetIt.instance<UserPreferences>();
  late final PluginSyncService? _watchedSync =
      GetIt.instance.isRegistered<PluginSyncService>()
      ? GetIt.instance<PluginSyncService>()
      : null;
  String _configurationScope = '';

  String _configurationKey() {
    final prefs = GetIt.instance<UserPreferences>();
    final sync = GetIt.instance.isRegistered<PluginSyncService>()
        ? GetIt.instance<PluginSyncService>()
        : null;
    return '${GetIt.instance<MediaServerClient>().userId}|'
        '${prefs.get(UserPreferences.kidsModeEnabled)}|'
        '${prefs.get(UserPreferences.blockedParentalRatings)}|'
        '${sync?.seerrAvailable}|${sync?.sonarrCalendarAvailable}|'
        '${sync?.seerrUrl}|${sync?.pluginVersion}';
  }

  void _onConfigurationChanged() {
    if (!mounted || _configurationScope == _configurationKey()) return;
    // Do not keep rows from a previous member/policy while the new scope loads.
    setState(() {
      _entries = [];
      _sourceRows.clear();
    });
    _generation++;
    unawaited(_calendarSubscription?.cancel());
    _refreshing = false;
    _refreshLoop.request();
  }

  Future<void> _load({bool force = false}) async {
    final generation = ++_generation;
    _refreshing = true;
    await _calendarSubscription?.cancel();
    if (!mounted || generation != _generation) return;
    final now = calendarEasternNow();
    _month = DateTime(now.year, now.month, now.day);
    final month = _month;
    setState(() {
      _loading = _entries.isEmpty;
      _refreshing = true;
      _partialFailure = false;
      _sourceFailures.clear();
    });
    final start = month;
    final end = start.add(const Duration(days: 90));
    final client = GetIt.instance<MediaServerClient>();
    final prefs = GetIt.instance<UserPreferences>();
    _configurationScope = _configurationKey();
    final sync = GetIt.instance.isRegistered<PluginSyncService>()
        ? GetIt.instance<PluginSyncService>()
        : null;
    final allowed =
        !prefs.get(UserPreferences.kidsModeEnabled) &&
        GetIt.instance.isRegistered<SeerrRepository>();
    final seerrEnabled = allowed && (sync?.seerrAvailable ?? false);
    final sonarrEnabled = allowed && (sync?.sonarrCalendarAvailable ?? false);
    final sources = <String, Future<List<CinematicCalendarEntry>> Function()>{};
    sources['Library'] = () async {
      final entries = <CinematicCalendarEntry>[];
      final result = await client.itemsApi
          .getItems(
            includeItemTypes: const ['Movie', 'Episode'],
            recursive: true,
            // Include the boundary day even when the browser is outside ET.
            minPremiereDate: DateTime.utc(
              start.year,
              start.month,
              start.day,
            ).subtract(const Duration(days: 1)),
            sortBy: 'PremiereDate',
            sortOrder: 'Ascending',
            limit: 1000,
            fields: 'PremiereDate,SeriesName,OfficialRating,ImageTags,BackdropImageTags,ParentBackdropItemId,ParentBackdropImageTags',
          )
          .timeout(const Duration(seconds: 12));
      for (final item
          in ((result['Items'] as List?) ?? const []).whereType<Map>()) {
        if (isRatingBlocked(item['OfficialRating']?.toString())) continue;
        final date = DateTime.tryParse('${item['PremiereDate'] ?? ''}');
        final id = item['Id']?.toString();
        if (date == null || id == null || id.isEmpty) continue;
        final series = item['SeriesName']?.toString();
        final title = item['Name']?.toString() ?? '';
        final tags = item['ImageTags'] as Map?;
        final primary = tags?['Primary']?.toString();
        final backdropTags = item['BackdropImageTags'] as List?;
        final parentTags = item['ParentBackdropImageTags'] as List?;
        final parentId = item['ParentBackdropItemId']?.toString();
        final artwork = backdropTags != null && backdropTags.isNotEmpty
            ? client.imageApi.getBackdropImageUrl(
                id,
                maxWidth: 640,
                tag: backdropTags.first.toString(),
              )
            : parentId != null && parentTags != null && parentTags.isNotEmpty
            ? client.imageApi.getBackdropImageUrl(
                parentId,
                maxWidth: 640,
                tag: parentTags.first.toString(),
              )
            : primary == null
            ? null
            : client.imageApi.getPrimaryImageUrl(
                id,
                maxWidth: 320,
                tag: primary,
              );
        entries.add(
          CinematicCalendarEntry(
            date: DateTime(date.year, date.month, date.day),
            isTv: item['Type'] == 'Episode' || series != null,
            availabilityLabel: 'Available',
            title: series ?? title,
            subtitle: series == null ? 'Library' : '$title · Library',
            imageUrl: artwork,
            route: Destinations.item(id),
            episodeKey: calendarEpisodeKey(
              series,
              item['ParentIndexNumber'],
              item['IndexNumber'],
            ),
          ),
        );
      }

      return entries;
    };
    if (seerrEnabled || sonarrEnabled) {
      Future<SeerrRepository> repository() => GetIt.instance
          .getAsync<SeerrRepository>()
          .timeout(const Duration(seconds: 15));
      String day(DateTime value) => DateFormat('yyyy-MM-dd').format(value);
      if (sonarrEnabled)
        sources['TV'] = () async {
          final entries = <CinematicCalendarEntry>[];
          final values = await (await repository())
              .getSonarrCalendar(
                start: day(start.subtract(const Duration(days: 1))),
                end: day(end.add(const Duration(days: 1))),
              )
              .timeout(const Duration(seconds: 65));
          for (final item in values.whereType<Map>()) {
            final series = item['series'];
            if (series is! Map) continue;
            final airing = sonarrCalendarDate(item);
            if (airing == null) continue;
            entries.add(
              CinematicCalendarEntry(
                date: airing.date,
                isTv: true,
                availabilityLabel: calendarAvailabilityLabel(item, tv: true),
                hasAirTime: airing.hasTime,
                timingPriority: 2,
                episodeKey: calendarEpisodeKey(
                  series['title']?.toString(),
                  item['seasonNumber'],
                  item['episodeNumber'],
                ),
                title: '${series['title'] ?? ''}',
                subtitle:
                    'S${item['seasonNumber'] ?? 1} · E${item['episodeNumber'] ?? 1} · ${item['title'] ?? ''} · TV',
                imageUrl: _remoteArtwork(series),
                route: sonarrCalendarRoute(item),
              ),
            );
          }

          return entries;
        };
      if (seerrEnabled)
        sources['Movies'] = () async {
          final entries = <CinematicCalendarEntry>[];
          final values = await (await repository())
              .getRadarrCalendar(start: day(start), end: day(end))
              .timeout(const Duration(seconds: 65));
          for (final item in values.whereType<Map>()) {
            final id = item['tmdbId']?.toString();
            final localId = calendarLocalItemId(item);
            if (localId == null && (id == null || id == '0')) continue;
            // Calendar APIs can return a film for any release in the interval.
            for (final release in [
              'digitalRelease',
              'physicalRelease',
              'inCinemas',
            ]) {
              final date = DateTime.tryParse('${item[release] ?? ''}');
              if (date == null) continue;
              entries.add(
                CinematicCalendarEntry(
                  date: DateTime(date.year, date.month, date.day),
                  title: '${item['title'] ?? ''}',
                  subtitle: calendarReleaseLabel(release),
                  imageUrl: _remoteArtwork(item),
                  route: localId == null
                      ? Destinations.seerrMedia(id!, mediaType: 'movie')
                      : Destinations.item(localId),
                  availabilityLabel: calendarAvailabilityLabel(item, tv: false),
                ),
              );
            }
          }

          return entries;
        };
    }
    _sourceRows.removeWhere((source, _) => !sources.containsKey(source));
    final loader = CalendarSourceLoader<CinematicCalendarEntry>();
    final scope =
        '$_configurationScope|${start.year}-${start.month}-${start.day}|$seerrEnabled|$sonarrEnabled|agenda-v1';
    _calendarSubscription = loader
        .load(
          scope: scope,
          sources: sources,
          force: force,
          discardOnFailure: (error) =>
              error is DioException &&
              (error.response?.statusCode == 401 ||
                  error.response?.statusCode == 403),
        )
        .listen((snapshot) {
          if (!mounted || generation != _generation) return;
          for (final entry in snapshot.sources.entries) {
            _sourceRows[entry.key] = entry.value;
          }
          for (final failure in snapshot.failures.entries) {
            final error = failure.value;
            if (error is DioException &&
                [401, 403].contains(error.response?.statusCode)) {
              _sourceRows.remove(failure.key);
            }
          }
          final rows = calendarEntriesForRange(
            _sourceRows.values.expand((rows) => rows),
            start,
            end,
          );
          setState(() {
            _entries = rows;
            _refreshing = snapshot.refreshing;
            _loading = rows.isEmpty && snapshot.refreshing;
            _partialFailure = snapshot.failures.isNotEmpty;
            _sourceFailures
              ..clear()
              ..addAll(
                snapshot.failures.map(
                  (name, error) => MapEntry(name, _calendarFailure(error)),
                ),
              );
          });
          if (!snapshot.refreshing) scheduleMicrotask(_refreshLoop.settled);
        });
  }

  @override
  void dispose() {
    _refreshLoop.dispose();
    routeLifecycleObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    _watchedPrefs.removeListener(_onConfigurationChanged);
    _watchedSync?.removeListener(_onConfigurationChanged);
    for (final node in _entryFocus.values) {
      node.dispose();
    }
    _generation++;
    unawaited(_calendarSubscription?.cancel());
    super.dispose();
  }

  int _artworkRank(Map image) {
    switch (image['coverType']?.toString().toLowerCase()) {
      case 'fanart':
        return 0;
      case 'screenshot':
        return 1;
      case 'banner':
        return 2;
      case 'poster':
        return 3;
      default:
        return 4;
    }
  }

  String? _remoteArtwork(Map item) {
    for (final image
        in (((item['images'] as List?) ?? const []).whereType<Map>().toList()
          ..sort((a, b) => _artworkRank(a).compareTo(_artworkRank(b))))) {
      final url = image['remoteUrl']?.toString();
      final uri = url == null ? null : Uri.tryParse(url);
      if (uri != null && (uri.scheme == 'https' || uri.scheme == 'http')) {
        return url;
      }
    }
    return null;
  }

  String _calendarFailure(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      final detail = data is Map ? data['error']?.toString() : null;
      const knownReasons = {
        'No admin Seerr session is available to read the arr settings':
            'Ask your administrator to check calendar access',
        'No sonarr server is configured in Seerr':
            'Ask your administrator to configure the TV calendar',
        'No radarr server is configured in Seerr':
            'Ask your administrator to configure the movie calendar',
        'No calendar connection is configured':
            'Configure the calendar connection in Spesh Base',
        'Could not reach the configured Sonarr calendar server':
            'TV calendar is unreachable; please retry',
      };
      if (knownReasons.containsKey(detail)) return knownReasons[detail]!;
      final code = error.response?.statusCode;
      if (code == 401 || code == 403)
        return 'Connection needs administrator attention';
      if (code == 404) return 'Calendar is not configured';
      if (code == 503) return 'Calendar connection is unavailable';
      if (code == 502) return 'Calendar server could not be reached';
      if (code != null) return 'Connection failed (HTTP $code)';
    }
    return 'Connection timed out or could not be loaded';
  }

  @override
  Widget build(BuildContext context) {
    final visibleEntries = filterCalendarEntries(_entries, _mediaFilter);
    final compact = MediaQuery.sizeOf(context).width < 760;
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColorScheme.background,
      body: NavigationLayout(
        activeRoute: Destinations.cinematicCalendar,
        showBackButton: true,
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              compact ? 16 : 112,
              compact ? 80 : 24,
              24,
              16,
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        'Today & upcoming',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.refresh,
                      onPressed: _refreshLoop.request,
                      style: calendarRefreshButtonStyle,
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
                if (_partialFailure)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          _sourceFailures.entries
                              .map((e) => '${e.key}: ${e.value}')
                              .join(' · '),
                        ),
                      ),
                      TextButton(
                        onPressed: _refreshLoop.request,
                        child: Text(l10n.retry),
                      ),
                    ],
                  ),
                SizedBox(
                  height: 3,
                  child: _refreshing ? const LinearProgressIndicator() : null,
                ),
                const SizedBox(height: 17),
                Text(
                  'Schedules are cached on the server and refreshed at midnight Eastern (EST/EDT). Times without a supplied air time are marked “Time unavailable”.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: CalendarMediaFilters(
                    selected: _mediaFilter,
                    onChanged: (value) => setState(() => _mediaFilter = value),
                  ),
                ),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : visibleEntries.isEmpty
                      ? Center(
                          child: Text(
                            _partialFailure
                                ? 'Could not load upcoming releases. Use Retry.'
                                : _refreshing
                                ? 'Loading upcoming releases…'
                                : 'No upcoming releases for this filter.',
                          ),
                        )
                      : ListView.builder(
                          key: ValueKey(_mediaFilter),
                          itemCount: visibleEntries.length,
                          findChildIndexCallback: (key) {
                            final index = visibleEntries.indexWhere(
                              (entry) =>
                                  ValueKey(calendarEntryIdentity(entry)) == key,
                            );
                            return index < 0 ? null : index;
                          },
                          itemBuilder: (context, index) {
                            final entry = visibleEntries[index];
                            final entryKey = calendarEntryIdentity(entry);
                            final focus = _entryFocus.putIfAbsent(
                              entryKey,
                              () => FocusNode(debugLabel: entry.title),
                            );
                            final accent = entry.isTv
                                ? const Color(0xFF8ABCF4)
                                : const Color(0xFFF3C564);
                            final date = calendarEasternDate(
                              entry.date,
                              hasAirTime: entry.hasAirTime,
                            );
                            final previous = index == 0
                                ? null
                                : calendarEasternDate(
                                    visibleEntries[index - 1].date,
                                    hasAirTime:
                                        visibleEntries[index - 1].hasAirTime,
                                  );
                            final heading = !DateUtils.isSameDay(
                              previous,
                              date,
                            );
                            return Column(
                              key: ValueKey(entryKey),
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (heading)
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      12,
                                      16,
                                      12,
                                      12,
                                    ),
                                    child: Text(
                                      DateFormat.MMMMEEEEd(
                                        Localizations.localeOf(context)
                                            .toString(),
                                      ).format(date),
                                    ),
                                  ),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 14),
                                  child: FocusableWrapper(
                                    key: ValueKey(entryKey),
                                    focusNode: focus,
                                    autoScroll: true,
                                    disableScale: true,
                                    onSelect: () => _openEntry(entry, focus),
                                    child: Card(
                                      color: const Color(0xFF151515),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(24),
                                        side: BorderSide(
                                          color: accent.withValues(alpha: 0.45),
                                        ),
                                      ),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(24),
                                        canRequestFocus: false,
                                        onTap: () => _openEntry(entry, focus),
                                        child: Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Row(
                                            children: [
                                              ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                                child: SizedBox(
                                                  width: compact ? 88 : 160,
                                                  height: compact ? 56 : 90,
                                                  child: entry.imageUrl == null
                                                      ? const ColoredBox(
                                                          color: Color(
                                                            0xFF25272C,
                                                          ),
                                                          child: Icon(
                                                            Icons
                                                                .movie_outlined,
                                                          ),
                                                        )
                                                      : BoundedNetworkImage(
                                                          imageUrl:
                                                              entry.imageUrl!,
                                                          maxWidth: 640,
                                                          fit: BoxFit.contain,
                                                        ),
                                                ),
                                              ),
                                              const SizedBox(width: 18),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      entry.title,
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .titleMedium,
                                                      maxLines: 2,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                    if (entry
                                                            .availabilityLabel !=
                                                        null)
                                                      Padding(
                                                        padding:
                                                            const EdgeInsets.only(
                                                              top: 4,
                                                            ),
                                                        child: Row(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            const Icon(
                                                              Icons
                                                                  .check_circle,
                                                              size: 14,
                                                              color: Color(
                                                                0xFF8CDDAB,
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                              width: 5,
                                                            ),
                                                            Flexible(
                                                              child: Text(
                                                                entry
                                                                    .availabilityLabel!,
                                                                style: const TextStyle(
                                                                  color: Color(
                                                                    0xFF8CDDAB,
                                                                  ),
                                                                  fontSize: 12,
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    const SizedBox(height: 6),
                                                    Text(
                                                      entry.subtitle,
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodySmall,
                                                    ),
                                                    if (compact)
                                                      Text(
                                                        entry.hasAirTime
                                                            ? '${DateFormat.jm().format(date)} ${date.timeZoneName}'
                                                            : 'Time unavailable',
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .bodySmall,
                                                      ),
                                                  ],
                                                ),
                                              ),
                                              if (!compact)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        left: 12,
                                                      ),
                                                  child: Text(
                                                    entry.hasAirTime
                                                        ? '${DateFormat.jm().format(date)} ${date.timeZoneName}'
                                                        : 'Time unavailable',
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .headlineSmall,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Switching filters operates only on this page's loaded entries.
class CalendarMediaFilters extends StatelessWidget {
  const CalendarMediaFilters({
    super.key,
    required this.selected,
    required this.onChanged,
  });
  final CalendarMediaFilter selected;
  final ValueChanged<CalendarMediaFilter> onChanged;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 12,
    runSpacing: 8,
    alignment: WrapAlignment.center,
    children: [
      for (final filter in CalendarMediaFilter.values)
        ChoiceChip(
          key: ValueKey(filter),
          selected: selected == filter,
          color: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.focused)
                ? const Color(0xFF2869AC)
                : states.contains(WidgetState.selected)
                ? const Color(0xFF28415D)
                : const Color(0xFF1B2330),
          ),
          labelStyle: const TextStyle(color: Colors.white),
          side: BorderSide(
            color: selected == filter
                ? const Color(0xFF8ABCF4)
                : const Color(0xFF64748B),
          ),
          avatar: filter == CalendarMediaFilter.all
              ? null
              : Icon(
                  filter == CalendarMediaFilter.tv
                      ? Icons.tv
                      : Icons.movie_outlined,
                  size: 18,
                  color: filter == CalendarMediaFilter.tv
                      ? const Color(0xFF8ABCF4)
                      : const Color(0xFFF3C564),
                ),
          label: Text(switch (filter) {
            CalendarMediaFilter.all => 'All',
            CalendarMediaFilter.tv => 'TV',
            CalendarMediaFilter.movies => 'Movies',
          }),
          onSelected: (_) => onChanged(filter),
        ),
    ],
  );
}

String calendarReleaseLabel(String release) => switch (release) {
  'digitalRelease' => 'Digital release',
  'physicalRelease' => 'Physical release',
  'inCinemas' => 'In cinemas',
  _ => 'Release',
};
final calendarRefreshButtonStyle = ButtonStyle(
  foregroundColor: const WidgetStatePropertyAll(Colors.white),
  backgroundColor: WidgetStateProperty.resolveWith(
    (states) => states.contains(WidgetState.focused)
        ? const Color(0xFF2869AC)
        : const Color(0xFF1B2330),
  ),
  side: const WidgetStatePropertyAll(BorderSide(color: Color(0xFF64748B))),
);
