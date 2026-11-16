import '../navigation/destinations.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../util/platform_detection.dart';

class StreamingServiceIcon extends StatelessWidget {
  const StreamingServiceIcon(this.name, {super.key});
  final String name;
  @override
  Widget build(BuildContext context) {
    final slug = switch (name) {
      'Netflix' => 'netflix',
      'Disney+' => 'disneyplus',
      'Prime Video' => 'amazonprime',
      'Apple TV+' => 'appletv',
      'Hulu' => 'hulu',
      'HBO Max' => 'hbo',
      'Paramount+' => 'paramountplus',
      'Peacock' => 'peacock',
      _ => 'discoveryplus',
    };
    return Semantics(
      label: name,
      child: Image.asset(
        'assets/icons/streaming/$slug.png',
        width: 64,
        height: 32,
        fit: BoxFit.contain,
      ),
    );
  }
}

/// Curated network discovery, not an assertion of regional streaming rights.
/// IDs reuse the existing Seerr network catalogue; HBO Max is TMDB network 3186.
const speshStreamingServices = <({String name, int networkId})>[
  (name: 'Netflix', networkId: 213),
  (name: 'Disney+', networkId: 2739),
  (name: 'Prime Video', networkId: 1024),
  (name: 'Apple TV+', networkId: 2552),
  (name: 'Hulu', networkId: 453),
  (name: 'HBO Max', networkId: 3186),
  (name: 'Paramount+', networkId: 4330),
  (name: 'Peacock', networkId: 3353),
  (name: 'Discovery+', networkId: 4353),
];

String streamingServiceRoute(String name) {
  final service = speshStreamingServices.firstWhere(
    (service) => service.name == name,
  );
  return Destinations.seerrBrowseWith(
    filterId: '${service.networkId}',
    filterName: service.name,
    mediaType: 'tv',
    filterType: 'network',
  );
}

/// Shared chooser for the toolbar, sidebar and phone hub.
Future<String?> pickSpeshStudio(BuildContext context) {
  if (PlatformDetection.isTV) {
    return showDialog<String>(
      context: context,
      builder: (_) => const _StudioRemoteDialog(),
    );
  }
  return showModalBottomSheet<String>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Studios & streaming services',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                ),
                const CloseButton(),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final service in speshStreamingServices)
                  Tooltip(
                    message: service.name,
                    child: SizedBox(
                      width: 124,
                      height: 100,
                      child: TextButton(
                        onPressed: () =>
                            Navigator.of(context).pop(service.name),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            StreamingServiceIcon(service.name),
                            const SizedBox(height: 10),
                            FittedBox(
                              child: Text(
                                service.name,
                                maxLines: 1,
                                softWrap: false,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _StudioRemoteDialog extends StatefulWidget {
  const _StudioRemoteDialog();

  @override
  State<_StudioRemoteDialog> createState() => _StudioRemoteDialogState();
}

class _StudioRemoteDialogState extends State<_StudioRemoteDialog> {
  final _nodes = [
    for (final service in speshStreamingServices)
      FocusNode(debugLabel: 'Studio ${service.name}'),
  ];

  @override
  void dispose() {
    for (final node in _nodes) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Studios & streaming services'),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (index, service) in speshStreamingServices.indexed)
              Focus(
                onKeyEvent: (_, event) {
                  if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
                    return KeyEventResult.ignored;
                  }
                  final key = event.logicalKey;
                  if (key == LogicalKeyboardKey.arrowDown ||
                      key == LogicalKeyboardKey.arrowUp) {
                    final next =
                        (index + (key == LogicalKeyboardKey.arrowDown ? 1 : -1))
                            .clamp(0, _nodes.length - 1);
                    _nodes[next].requestFocus();
                    return KeyEventResult.handled;
                  }
                  if (key == LogicalKeyboardKey.select ||
                      key == LogicalKeyboardKey.enter ||
                      key == LogicalKeyboardKey.gameButtonA) {
                    if (event is KeyDownEvent) {
                      Navigator.of(context).pop(service.name);
                    }
                    return KeyEventResult.handled;
                  }
                  if (key == LogicalKeyboardKey.escape ||
                      key == LogicalKeyboardKey.goBack) {
                    Navigator.of(context).pop();
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: TextButton(
                  focusNode: _nodes[index],
                  autofocus: index == 0,
                  onFocusChange: (focused) {
                    final itemContext = _nodes[index].context;
                    if (focused && itemContext != null) {
                      Scrollable.ensureVisible(
                        itemContext,
                        alignment: 0.5,
                        duration: Duration.zero,
                      );
                    }
                  },
                  onPressed: () => Navigator.of(context).pop(service.name),
                  child: Row(
                    children: [
                      StreamingServiceIcon(service.name),
                      const SizedBox(width: 16),
                      Expanded(child: Text(service.name)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Close'),
      ),
    ],
  );
}

/// Only curated network filters light the Studios destination.
bool isSpeshStudioRoute(String route) {
  final uri = Uri.tryParse(route);
  if (uri == null || uri.path != '/seerr/browse') return false;
  final query = uri.queryParameters;
  return query['filterType'] == 'network' &&
      query['mediaType'] == 'tv' &&
      speshStreamingServices.any(
        (service) => '${service.networkId}' == query['filterId'],
      );
}
