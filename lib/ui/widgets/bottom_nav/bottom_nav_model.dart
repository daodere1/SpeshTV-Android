import '../../../preference/bottom_nav_tabs.dart';
import '../../navigation/destinations.dart';
import '../spesh_streaming_services.dart';

enum BottomNavItemKind { home, tab, studios, you }

/// One cell on the bar. [slot] is the cell's place among the offered items,
/// which is what the theme's navbar colour cycle is keyed on.
class BottomNavBarItem {
  final BottomNavItemKind kind;
  final BottomNavTab? tab;
  final int slot;

  const BottomNavBarItem._(this.kind, this.tab, this.slot);

  const BottomNavBarItem.home() : this._(BottomNavItemKind.home, null, 0);

  const BottomNavBarItem.tab(BottomNavTab tab, int slot)
      : this._(BottomNavItemKind.tab, tab, slot);

  const BottomNavBarItem.studios(int slot)
      : this._(BottomNavItemKind.studios, null, slot);

  const BottomNavBarItem.you(int slot)
      : this._(BottomNavItemKind.you, null, slot);

  String get id => switch (kind) {
        BottomNavItemKind.home => 'home',
        BottomNavItemKind.studios => 'studios',
        BottomNavItemKind.you => 'you',
        BottomNavItemKind.tab => tab!.name,
      };

  @override
  bool operator ==(Object other) =>
      other is BottomNavBarItem &&
      other.kind == kind &&
      other.tab == tab &&
      other.slot == slot;

  @override
  int get hashCode => Object.hash(kind, tab, slot);

  @override
  String toString() => 'BottomNavBarItem($id, slot $slot)';
}

/// Home, the pinned tabs and You, with slots handed out over the offered pins
/// so a tab hidden for want of data doesn't recolour the ones after it.
///
/// [withoutSearch] is for Split, which gives Search a button of its own.
/// [isAvailable] hides pins whose data isn't there, like Libraries before any
/// library has loaded.
List<BottomNavBarItem> resolveBarItems(
  BottomNavTabGates gates,
  String rawPins, {
  bool withoutSearch = false,
  bool speshPresentation = false,
  bool Function(BottomNavTab tab)? isAvailable,
}) {
  final pins = gates
      .resolvePins(rawPins)
      .where((t) => !withoutSearch || t != BottomNavTab.search)
      .where((t) => !speshPresentation ||
          (t != BottomNavTab.favorites && t != BottomNavTab.genres))
      .toList();
  final items = <BottomNavBarItem>[const BottomNavBarItem.home()];
  final studios = speshPresentation && !gates.kidsMode;
  // Studios shares the existing pin budget and stays beside Search. Split
  // already has Search in its own capsule, so Studios leads the tab group.
  final visiblePins = pins.take(studios ? kMaxPinnedBottomNavTabs - 1
      : kMaxPinnedBottomNavTabs).toList();
  var slot = 1;
  if (studios && !visiblePins.contains(BottomNavTab.search)) {
    items.add(BottomNavBarItem.studios(slot++));
  }
  for (var i = 0; i < visiblePins.length; i++) {
    final tab = visiblePins[i];
    final tabSlot = slot++;
    if (isAvailable == null || isAvailable(tab)) {
      items.add(BottomNavBarItem.tab(tab, tabSlot));
    }
    if (studios && tab == BottomNavTab.search) {
      items.add(BottomNavBarItem.studios(slot++));
    }
  }
  items.add(BottomNavBarItem.you(slot));
  return items;
}

/// Where each tab's own screens live, for lighting it up as the active one.
bool bottomNavTabMatchesRoute(BottomNavTab tab, String route) {
  bool under(String prefix) => route == prefix || route.startsWith('$prefix/');
  return switch (tab) {
    BottomNavTab.search => route == Destinations.search,
    BottomNavTab.libraries => under('/library') ||
        under('/library-view') ||
        under('/folder') ||
        under('/music') ||
        under('/books') ||
        under('/games'),
    BottomNavTab.favorites => route == Destinations.allFavorites,
    BottomNavTab.genres => route == Destinations.allGenres,
    BottomNavTab.liveTv => under(Destinations.liveTv),
    BottomNavTab.discover => under('/seerr'),
  };
}

/// The index of the item to highlight, or null when the screen belongs to
/// none of them, like an item's detail page.
int? activeBarIndex(
  List<BottomNavBarItem> items,
  String? activeRoute, {
  required bool hubOpen,
}) {
  final route = activeRoute ?? '';
  if (!hubOpen && isSpeshStudioRoute(route)) {
    final studios = items.indexWhere((item) => item.kind == BottomNavItemKind.studios);
    if (studios >= 0) return studios;
  }
  for (var i = 0; i < items.length; i++) {
    final item = items[i];
    final active = switch (item.kind) {
      BottomNavItemKind.studios => !hubOpen && isSpeshStudioRoute(route),
      BottomNavItemKind.you => hubOpen,
      BottomNavItemKind.home => !hubOpen && route == Destinations.home,
      BottomNavItemKind.tab =>
        !hubOpen && bottomNavTabMatchesRoute(item.tab!, route),
    };
    if (active) return i;
  }
  return null;
}

enum BottomNavHubAction {
  studios,
  calendar,
  saved,
  shuffle,
  syncPlay,
  quickConnect,
  remoteControl,
}

/// A tile in the bottom navbar hub: a destination that isn't pinned, or an
/// action.
class BottomNavHubTile {
  final BottomNavTab? tab;
  final BottomNavHubAction? action;

  const BottomNavHubTile.tab(BottomNavTab this.tab) : action = null;
  const BottomNavHubTile.action(BottomNavHubAction this.action) : tab = null;

  @override
  bool operator ==(Object other) =>
      other is BottomNavHubTile && other.tab == tab && other.action == action;

  @override
  int get hashCode => Object.hash(tab, action);

  @override
  String toString() => 'BottomNavHubTile(${tab?.name ?? action?.name})';
}

/// Tiles for the bottom navbar hub, in the order they are drawn: saved media
/// first because it matters most offline, then every destination that is
/// offered but not on the bar, then the actions.
///
/// [alsoOnBar] names tabs the bar shows outside its tab row, like Split's
/// search button.
List<BottomNavHubTile> resolveHubTiles({
  required BottomNavTabGates gates,
  required List<BottomNavBarItem> barItems,
  required bool Function(BottomNavTab tab) isAvailable,
  bool speshPresentation = false,
  required bool savedAvailable,
  required bool shuffle,
  required bool syncPlay,
  required bool quickConnect,
  Set<BottomNavTab> alsoOnBar = const {},
}) {
  final onBar = {
    ...alsoOnBar,
    for (final item in barItems)
      if (item.tab != null) item.tab!,
  };
  return [
    if (speshPresentation && !gates.kidsMode)
      const BottomNavHubTile.action(BottomNavHubAction.studios),
    if (speshPresentation && !gates.kidsMode)
      const BottomNavHubTile.action(BottomNavHubAction.calendar),
    if (savedAvailable) const BottomNavHubTile.action(BottomNavHubAction.saved),
    for (final tab in BottomNavTab.values)
      if (!onBar.contains(tab) && gates.offers(tab) && isAvailable(tab) &&
          (!speshPresentation ||
              (tab != BottomNavTab.favorites && tab != BottomNavTab.genres)))
        BottomNavHubTile.tab(tab),
    if (shuffle && !speshPresentation) const BottomNavHubTile.action(BottomNavHubAction.shuffle),
    if (syncPlay) const BottomNavHubTile.action(BottomNavHubAction.syncPlay),
    if (quickConnect)
      const BottomNavHubTile.action(BottomNavHubAction.quickConnect),
    const BottomNavHubTile.action(BottomNavHubAction.remoteControl),
  ];
}
