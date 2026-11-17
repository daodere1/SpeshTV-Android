const speshCurrentReleaseNotes = <String>[
  'Calendar: Today & upcoming, All / TV / Movies filters, Eastern air times and full artwork.',
  'Calendar rereads the shared server schedule and local availability about every minute while visible. Refresh pauses in the background.',
  'Local movies and episodes show Available; series-only matches show Series available. Calendar updates preserve filters, scroll and focus.',
  'Studios: full-color service artwork, clapperboard shortcut, and reliable navigation after closing the chooser.',
  'Episode browsing: current/resumable episode positioning, anime badges, touch long-press and held-OK actions.',
];
List<String> speshReleaseNotesForBuild(String build) => switch (build) {
  '30000206' || '2000073' => speshCurrentReleaseNotes,
  '30000205' || '2000072' => const [
    'Shared Core calendar with TV/movie filters, local availability and Eastern times.',
    'Fixed studio chooser navigation when navigation chrome rebuilds.',
  ],
  _ => const [
    'Release notes for this SpeshTV build are not bundled. Check the SpeshTV GitHub releases page for details.',
  ],
};
