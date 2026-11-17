import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:jellyfin_preference/jellyfin_preference.dart';
import 'package:moonfin/auth/repositories/session_repository.dart';
import 'package:moonfin/data/repositories/seerr_repository.dart';
import 'package:server_core/server_core.dart';

class _Client extends Mock implements MediaServerClient {}

class _Store extends Mock implements PreferenceStore {}

class _Session extends Mock implements SessionRepository {}

void main() {
  test(
    'calendar uses Jellyfin authorization without a Seerr status/login probe',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final paths = <String>[];
      final auth = <String?>[];
      server.listen((request) async {
        paths.add(request.uri.path);
        auth.add(request.headers.value('Authorization'));
        request.response.headers.contentType = ContentType.json;
        request.response.write('[{"airDateUtc":"2026-11-15T02:00:00Z"}]');
        await request.response.close();
      });
      final client = _Client();
      when(() => client.baseUrl).thenReturn('http://127.0.0.1:${server.port}');
      when(() => client.accessToken).thenReturn('test-token');
      final repository = SeerrRepository(_Store(), _Session(), client);
      try {
        final result = await repository.getSonarrCalendar(
          start: '2026-11-01',
          end: '2026-12-01',
        );
        expect(result.single['airDateUtc'], '2026-11-15T02:00:00Z');
        expect(paths, ['/Moonfin/Seerr/Sonarr/Calendar']);
        expect(auth.single, contains('test-token'));
      } finally {
        repository.close();
        await server.close(force: true);
      }
    },
  );
  test(
    'each shared-calendar read reaches Core and preserves local-match fields',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final paths = <String>[];
      final auth = <String?>[];
      server.listen((request) async {
        paths.add(request.uri.path);
        auth.add(request.headers.value('Authorization'));
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          '[{"moonfinItemId":"local","moonfinEpisodeId":"episode","moonfinLibraryIds":["visible-folder"],"hasFile":false}]',
        );
        await request.response.close();
      });
      final client = _Client();
      when(() => client.baseUrl).thenReturn('http://127.0.0.1:${server.port}');
      when(() => client.accessToken).thenReturn('member-one');
      final repository = SeerrRepository(_Store(), _Session(), client);
      try {
        final first = await repository.getSonarrCalendar(
          start: '2026-11-16',
          end: '2027-02-14',
        );
        expect(first.single['moonfinEpisodeId'], 'episode');
        expect(first.single['moonfinLibraryIds'], ['visible-folder']);
        await repository.getSonarrCalendar(
          start: '2026-11-16',
          end: '2027-02-14',
        );
        when(() => client.accessToken).thenReturn('member-two');
        final movie = await repository.getRadarrCalendar(
          start: '2026-11-16',
          end: '2027-02-14',
        );
        expect(movie.single['moonfinItemId'], 'local');
        expect(paths, [
          '/Moonfin/Seerr/Sonarr/Calendar',
          '/Moonfin/Seerr/Sonarr/Calendar',
          '/Moonfin/Seerr/Radarr/Calendar',
        ]);
        expect(auth.take(2).every((a) => a!.contains('member-one')), isTrue);
        expect(auth.last, contains('member-two'));
        expect(auth.last, isNot(contains('member-one')));
      } finally {
        repository.close();
        await server.close(force: true);
      }
    },
  );
}
