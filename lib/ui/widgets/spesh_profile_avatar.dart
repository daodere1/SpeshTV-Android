import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../auth/repositories/session_repository.dart';

const speshProfileColors = <String, Color>{
  'blue': Color(0xFF2375CF),
  'gold': Color(0xFFBB8426),
  'teal': Color(0xFF168B8A),
  'purple': Color(0xFF7853AD),
  'coral': Color(0xFFC75D50),
  'green': Color(0xFF528546),
  'pink': Color(0xFFB85388),
  'slate': Color(0xFF53677E),
};
const _avatarIcons = [
  Icons.face_rounded,
  Icons.sentiment_very_satisfied_rounded,
  Icons.pets_rounded,
  Icons.rocket_launch_rounded,
  Icons.local_florist_rounded,
  Icons.forest_rounded,
  Icons.auto_awesome_rounded,
  Icons.smart_toy_rounded,
];

class SpeshProfileAvatar extends StatelessWidget {
  const SpeshProfileAvatar({super.key, required this.avatar, this.size = 112});
  final String avatar;
  final double size;
  @override
  Widget build(BuildContext context) {
    final index = speshProfileColors.keys.toList().indexOf(avatar);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: speshProfileColors[avatar] ?? speshProfileColors['blue'],
        borderRadius: BorderRadius.circular(size * .16),
      ),
      child: Icon(
        _avatarIcons[index < 0 ? 0 : index],
        color: Colors.white,
        size: size * .62,
      ),
    );
  }
}

Widget? currentSpeshProfileAvatar(double size) {
  if (!GetIt.instance.isRegistered<SessionRepository>()) return null;
  final avatar = GetIt.instance<SessionRepository>().selectedSpeshProfileAvatar;
  return avatar == null ? null : SpeshProfileAvatar(avatar: avatar, size: size);
}
