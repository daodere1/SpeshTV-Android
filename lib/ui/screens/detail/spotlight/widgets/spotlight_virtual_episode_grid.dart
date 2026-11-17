import '../../../../navigation/route_lifecycle_observer.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';
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

  String? _anchor;
  bool _positioned = false;
  int _generation = 0;
  @override
  void dispose() {
    routeLifecycleObserver.unsubscribe(this);
    _generation++;
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty)
      return const Center(child: Text('No episodes available.'));
    _anchor ??= widget
        .items[spotlightInitialEpisodeIndex(
              widget.items,
              widget.currentItemId,
            ) ??
            0]
        .id;
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
        final target = widget.items.indexWhere((item) => item.id == _anchor);
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
                  PlatformDetection.isTV &&
                  (ModalRoute.of(context)?.isCurrent ?? true) &&
                  widget.firstFocusNode?.context != null) {
                widget.firstFocusNode?.requestFocus();
              }
            }

            if (widget.firstFocusNode?.context != null)
              focusTarget();
            else
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => focusTarget(),
              );
          });
        }
        final rows = (widget.items.length / metrics.columns).ceil();
        return ListView.builder(
          controller: _scroll,
          primary: false,
          itemExtent: extent,
          cacheExtent: extent * 2,
          itemCount: rows,
          itemBuilder: (context, row) {
            final start = row * metrics.columns;
            final end = math.min(start + metrics.columns, widget.items.length);
            final entries = widget.items.sublist(start, end);
            final containsAnchor = entries.any((item) => item.id == _anchor);
            return SpotlightMediaGridSection(
              key: ValueKey(entries.first.id),
              items: entries,
              imageApi: widget.imageApi,
              prefs: widget.prefs,
              aspectRatio: 16 / 9,
              landscapeCells: true,
              anchorOnOpen: false,
              currentItemId: containsAnchor ? _anchor : widget.currentItemId,
              firstFocusNode: containsAnchor ? widget.firstFocusNode : null,
              onItemTap: widget.onItemTap,
              onItemChanged: widget.onItemChanged,
            );
          },
        );
      },
    );
  }
}
