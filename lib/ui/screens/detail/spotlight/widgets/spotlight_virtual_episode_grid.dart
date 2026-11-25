import '../../../../navigation/route_lifecycle_observer.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:server_core/server_core.dart';

import '../../../../../data/models/aggregated_item.dart';
import '../../../../../preference/user_preferences.dart';
import '../../../../../util/platform_detection.dart';
import 'spotlight_modal_grids.dart';

/// A bounded viewport owns the scroll; only nearby rows create cards/badges.
/// The complete season remains in items and is never truncated to a window.
class SpotlightVirtualEpisodeGrid extends StatefulWidget {
  const SpotlightVirtualEpisodeGrid({
    super.key,
    required this.items,
    required this.imageApi,
    required this.prefs,
    required this.onItemTap,
    this.onItemChanged,
    this.firstFocusNode,
    this.currentItemId,
  });
  final List<AggregatedItem> items;
  final ImageApi imageApi;
  final UserPreferences prefs;
  final ValueChanged<AggregatedItem> onItemTap;
  final VoidCallback? onItemChanged;
  final FocusNode? firstFocusNode;
  final String? currentItemId;
  @override
  State<SpotlightVirtualEpisodeGrid> createState() =>
      _SpotlightVirtualEpisodeGridState();
}

class _SpotlightVirtualEpisodeGridState
    extends State<SpotlightVirtualEpisodeGrid>
    with RouteAware {
  final _scroll = ScrollController();
  ModalRoute<dynamic>? _observedRoute;
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
    _generation++;
    if (_scroll.hasClients) _scroll.jumpTo(_scroll.offset);
  }

  late List<AggregatedItem> _items = _uniqueEpisodes(widget.items);

  static List<AggregatedItem> _uniqueEpisodes(List<AggregatedItem> items) {
    final seen = <String>{};
    return [
      for (final item in items)
        if (seen.add(item.id)) item,
    ];
  }

  final _episodeNodes = <String, FocusNode>{};
  String? _focusedEpisode;
  String? _anchor;
  String? _initialAnchor;

  FocusNode _node(String id) =>
      id == _initialAnchor && widget.firstFocusNode != null
      ? widget.firstFocusNode!
      : _episodeNodes.putIfAbsent(id, () => FocusNode(debugLabel: id));

  @override
  void didUpdateWidget(covariant SpotlightVirtualEpisodeGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.items, widget.items)) return;
    _items = _uniqueEpisodes(widget.items);
    final id = _focusedEpisode;
    if (id == null || !_node(id).hasFocus) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !(ModalRoute.of(context)?.isCurrent ?? true) ||
          _focusedEpisode != id ||
          _node(id).hasFocus)
        return;
      if (_items.any((item) => item.id == id)) {
        if (_node(id).context == null) {
          setState(() {
            _anchor = id;
            _positioned = false;
          });
        } else {
          _node(id).requestFocus();
        }
      }
    });
  }

  bool _positioned = false;
  int _generation = 0;
  @override
  void dispose() {
    routeLifecycleObserver.unsubscribe(this);
    _generation++;
    _scroll.dispose();
    for (final node in _episodeNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty)
      return const Center(child: Text('No episodes available.'));
    _anchor ??=
        _items[spotlightInitialEpisodeIndex(_items, widget.currentItemId) ?? 0]
            .id;
    _initialAnchor ??= _anchor;
    return LayoutBuilder(
      builder: (context, constraints) {
        assert(
          constraints.hasBoundedHeight,
          'Episode viewport must be bounded by the modal.',
        );
        final expanded = widget.prefs.get(UserPreferences.cardFocusExpansion);
        final metrics = spotlightGridMetrics(
          maxWidth: constraints.maxWidth,
          desiredWidth: 220,
          minColumns: 2,
          maxColumns: 5,
          aspectRatio: 16 / 9,
          focusExpansion: expanded,
          maxCellWidth: 300,
        );
        final extent =
            metrics.cellWidth / (16 / 9) +
            72 * MediaQuery.textScalerOf(context).scale(1) +
            metrics.runSpacing * (expanded ? 2 : 1);
        final target = _items.indexWhere((item) => item.id == _anchor);
        if (!_positioned && target >= 0) {
          _positioned = true;
          final generation = _generation;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted ||
                generation != _generation ||
                !_scroll.hasClients ||
                !(ModalRoute.of(context)?.isCurrent ?? true))
              return;
            _scroll.jumpTo(
              ((target ~/ metrics.columns) * extent).clamp(
                0,
                _scroll.position.maxScrollExtent,
              ),
            );
            void focusTarget() {
              if (mounted &&
                  generation == _generation &&
                  (PlatformDetection.isTV || _focusedEpisode != null) &&
                  (ModalRoute.of(context)?.isCurrent ?? true) &&
                  _node(_anchor!).context != null) {
                _node(_anchor!).requestFocus();
              }
            }

            if (_node(_anchor!).context != null)
              focusTarget();
            else
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => focusTarget(),
              );
          });
        }
        final rows = (_items.length / metrics.columns).ceil();
        return Focus(
          canRequestFocus: false,
          onKeyEvent: (_, event) {
            if (event is! KeyDownEvent && event is! KeyRepeatEvent)
              return KeyEventResult.ignored;
            final key = event.logicalKey;
            if (key != LogicalKeyboardKey.arrowDown &&
                key != LogicalKeyboardKey.arrowUp) {
              return KeyEventResult.ignored;
            }
            final index = _items.indexWhere(
              (item) => item.id == _focusedEpisode,
            );
            if (index < 0 || !_node(_items[index].id).hasFocus)
              return KeyEventResult.ignored;
            final row = index ~/ metrics.columns;
            final nextRow =
                row + (key == LogicalKeyboardKey.arrowDown ? 1 : -1);
            if (nextRow < 0 || nextRow >= rows) return KeyEventResult.ignored;
            final nextIndex = math.min(
              nextRow * metrics.columns + index % metrics.columns,
              _items.length - 1,
            );
            final sourceId = _items[index].id;
            final nextId = _items[nextIndex].id;
            final nextNode = _node(nextId);
            if (nextNode.context != null) {
              nextNode.requestFocus();
            } else {
              _scroll.jumpTo(
                (nextRow * extent).clamp(0.0, _scroll.position.maxScrollExtent),
              );
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted &&
                    (ModalRoute.of(context)?.isCurrent ?? true) &&
                    _focusedEpisode == sourceId &&
                    nextNode.context != null)
                  nextNode.requestFocus();
              });
            }
            return KeyEventResult.handled;
          },
          child: ListView.builder(
            controller: _scroll,
            primary: false,
            itemExtent: extent,
            cacheExtent: extent * 2,
            itemCount: rows,
            itemBuilder: (context, row) {
              final start = row * metrics.columns;
              final end = math.min(start + metrics.columns, _items.length);
              final entries = _items.sublist(start, end);

              return SpotlightMediaGridSection(
                key: ValueKey(entries.first.id),
                items: entries,
                imageApi: widget.imageApi,
                prefs: widget.prefs,
                aspectRatio: 16 / 9,
                landscapeCells: true,
                anchorOnOpen: false,
                currentItemId: widget.currentItemId,
                episodeFocusNode: (item) => _node(item.id),
                onEpisodeFocus: (item) => _focusedEpisode = item.id,
                onItemTap: widget.onItemTap,
                onItemChanged: widget.onItemChanged,
              );
            },
          ),
        );
      },
    );
  }
}
