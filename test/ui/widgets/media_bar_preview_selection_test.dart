import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/data/models/media_bar_slide_item.dart';
import 'package:moonfin/ui/widgets/media_bar.dart';

MediaBarSlideItem slide({
  String id = 'item',
  String server = 'server',
  String title = 'Selected title',
  String tmdb = '123',
  String imdb = 'tt123',
  int year = 2026,
}) => MediaBarSlideItem(
  itemId: id, serverId: server, title: title,
  tmdbId: tmdb, imdbId: imdb, year: year,
);

void main() {
  test('refreshed instances of the same title accept the resolved preview', () {
    expect(mediaBarTrailerSelectionMatches(slide(), slide()), isTrue);
  });

  test('stale resolutions cannot bind to another selection or provider', () {
    final requested = slide();
    for (final selected in <MediaBarSlideItem?>[
      null,
      slide(id: 'other'),
      slide(server: 'other-server'),
      slide(title: 'Replacement title'),
      slide(tmdb: '456'),
      slide(imdb: 'tt456'),
      slide(year: 2025),
    ]) {
      expect(mediaBarTrailerSelectionMatches(selected, requested), isFalse);
    }
  });
}
