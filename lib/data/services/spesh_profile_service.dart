import 'package:dio/dio.dart';
import 'package:server_core/server_core.dart';

const speshProfileAvatars = [
  'blue',
  'gold',
  'teal',
  'purple',
  'coral',
  'green',
  'pink',
  'slate',
];

class SpeshViewingProfile {
  const SpeshViewingProfile({
    required this.id,
    required this.name,
    required this.avatar,
    required this.isPrimary,
  });
  final String id, name, avatar;
  final bool isPrimary;
  factory SpeshViewingProfile.fromJson(Map<String, dynamic> data) =>
      SpeshViewingProfile(
        id: data['id'] as String,
        name: data['name'] as String,
        avatar: data['avatar'] as String,
        isPrimary: data['isPrimary'] == true,
      );
}

class SpeshProfileSelection {
  SpeshProfileSelection.fromJson(Map<String, dynamic> data)
    : userId = data['userId'] as String,
      token = data['accessToken'] as String?;
  final String userId;
  final String? token;
  String validatedToken(
    SpeshViewingProfile profile,
    String ownerId,
    String ownerToken,
  ) {
    if (profile.id == 'main' && profile.isPrimary && userId == ownerId)
      return ownerToken;
    if (profile.id == 'main' ||
        profile.isPrimary ||
        userId.isEmpty ||
        userId == ownerId ||
        token == null ||
        token!.isEmpty) {
      throw StateError('The server returned an invalid profile identity.');
    }
    return token!;
  }
}

class SpeshProfilesUnavailable implements Exception {}

/// Uses the original account for management even while a managed identity is active.
class SpeshViewingProfilesApi {
  SpeshViewingProfilesApi({
    required this.baseUrl,
    required this.ownerToken,
    required this.deviceInfo,
    Dio? dio,
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 15),
               receiveTimeout: const Duration(seconds: 30),
             ),
           );
  final String baseUrl, ownerToken;
  final DeviceInfo deviceInfo;
  final Dio _dio;
  Future<dynamic> _request(
    String path, {
    String method = 'GET',
    Object? body,
  }) async {
    try {
      final response = await _dio.request(
        '${baseUrl.replaceFirst(RegExp(r'/+$'), '')}/Spesh/Profiles$path',
        data: body,
        options: Options(
          method: method,
          headers: {
            'Authorization': buildServerAuthorizationHeader(
              scheme: 'MediaBrowser',
              deviceInfo: deviceInfo,
              accessToken: ownerToken,
            ),
            'Cache-Control': 'no-store',
          },
        ),
      );
      return response.data;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404 || e.response?.statusCode == 501)
        throw SpeshProfilesUnavailable();
      rethrow;
    }
  }

  Future<List<SpeshViewingProfile>> list() async {
    final data = await _request('');
    final profiles = (data['profiles'] as List)
        .map(
          (p) =>
              SpeshViewingProfile.fromJson(Map<String, dynamic>.from(p as Map)),
        )
        .toList();
    if (profiles.length > 3 ||
        !profiles.any((p) => p.id == 'main' && p.isPrimary))
      throw const FormatException('Invalid profile list');
    return profiles;
  }

  static void validate(String name, String avatar) {
    if (name.trim().isEmpty ||
        name.trim().length > 24 ||
        !speshProfileAvatars.contains(avatar)) {
      throw ArgumentError(
        'Enter a name of 1–24 characters and choose an avatar.',
      );
    }
  }

  Future<void> save({
    SpeshViewingProfile? profile,
    required String name,
    required String avatar,
  }) async {
    validate(name, avatar);
    await _request(
      profile == null ? '' : '/${Uri.encodeComponent(profile.id)}',
      method: profile == null ? 'POST' : 'PUT',
      body: {'name': name.trim(), 'avatar': avatar},
    );
  }

  Future<SpeshProfileSelection> select(
    SpeshViewingProfile profile, {
    Future<void> Function()? beforeSelect,
  }) async {
    // Do not change Core's device session until the old user's reports drain.
    await beforeSelect?.call();
    return SpeshProfileSelection.fromJson(
      Map<String, dynamic>.from(
        await _request(
          '/${Uri.encodeComponent(profile.id)}/Select',
          method: 'POST',
        ) as Map,
      ),
    );
  }

  void dispose() => _dio.close();
}
