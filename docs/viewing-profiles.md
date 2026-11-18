# Viewing profiles (Android candidate)

SpeshTV Core 3.1.0.9 provides up to three viewing profiles per Jellyfin account. The native phone, tablet, and TV layouts show **Who’s watching?** after each cold sign-in/restore. Use **Switch profile** in the account menu to return to the picker. Names and the eight original avatars can be edited there.

The original profile retains its Jellyfin identity and history. Additional profiles use managed identities with separate watched state, resume/Next Up, and favorites. Their tokens remain in memory; the saved login and profile-management requests retain the original account credentials. Switching drains playback and remote commands before changing identity, then replaces scoped clients, models, sockets, and caches. A missing managed session fails closed instead of falling back to a saved owner account. Avatars do not select a Kids policy; server restrictions remain authoritative.

If Core is unavailable, **Continue with original account** preserves the existing account experience. Managed profiles currently use online playback. Offline downloads, automatic downloads, OS media resumption, and TV launcher recommendations remain with the original account, avoiding persisted managed-profile credentials in background tasks.

These are candidate builds, not a published release. Automated API, credential-isolation, cache, phone/TV picker, and existing playback/navigation regressions are run before packaging. Physical phone/Shield profile switching, two-user watch-state changes, and cold-launch/deep-link checks still require device verification. Existing calendar, studio, season/episode, live TV, and playback fixes are preserved.
