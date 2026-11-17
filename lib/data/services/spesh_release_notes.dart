const speshCurrentReleaseNotes = <String>[
  'More Episodes opens a season picker first, including one-season shows. Back returns to the selected season.',
  'Long seasons use a bounded, virtualized episode viewport, preserving all episodes and in-place updates.',
  'Calendar: Today & upcoming, All / TV / Movies filters, Eastern air times and full artwork.',
  'Calendar rereads the shared server schedule and local availability about every minute while visible. Refresh pauses in the background.',
  'Local movies and episodes show Available; series-only matches show Series available. Calendar updates preserve filters, scroll and focus.',
  'Studios: full-color service artwork, clapperboard shortcut, and reliable navigation after closing the chooser.',
  'Episode browsing: current/resumable episode positioning, anime badges, touch long-press and held-OK actions.',
];
List<String> speshReleaseNotesForBuild(String build) => switch (build) {
  '30000207' || '2000074' => speshCurrentReleaseNotes,
  '30000206' || '2000073' => const [
    'Calendar rereads the shared server schedule about every minute while visible, with readable TV and movie filters.',
    'Studios navigation and bundled SpeshTV release notes.',
  ],
  '30000205' || '2000072' => const [
    'Shared Core calendar with TV/movie filters, local availability and Eastern times.',
    'Fixed studio chooser navigation when navigation chrome rebuilds.',
  ],
  _ => const [
    'Release notes for this SpeshTV build are not bundled. Check the SpeshTV GitHub releases page for details.',
  ],
};
