import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../data/services/spesh_release_notes.dart';

class SpeshWhatsNewScreen extends StatefulWidget {
  const SpeshWhatsNewScreen({super.key, this.buildNumber});
  final String? buildNumber;
  @override
  State<SpeshWhatsNewScreen> createState() => _SpeshWhatsNewScreenState();
}

class _SpeshWhatsNewScreenState extends State<SpeshWhatsNewScreen> {
  late final Future<String> _build = widget.buildNumber != null
      ? Future.value(widget.buildNumber)
      : PackageInfo.fromPlatform()
            .then((info) => info.buildNumber)
            .catchError((Object _) => 'unknown');
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF10151D),
    appBar: AppBar(title: const Text('What’s New in SpeshTV')),
    body: FutureBuilder<String>(
      future: _build,
      builder: (context, result) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Build ${result.data ?? '…'}',
            style: const TextStyle(color: Color(0xFF8ABCF4), fontSize: 18),
          ),
          const SizedBox(height: 16),
          for (final note in speshReleaseNotesForBuild(
            result.data ?? 'unknown',
          ))
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Text(
                note,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  height: 1.5,
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
