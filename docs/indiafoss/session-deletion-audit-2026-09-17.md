# Session deletion audit, iOS (17 September 2026)

`docs/architecture/ios.md` in the Companion repository asks, before any
mesh work lands here: "Audit transient restoration errors so unavailable
mesh transport cannot cause credential/database deletion." This is that
audit for the current `develop` snapshot, done by reading the source.
Nothing here is a device result; there is no signed device build yet.

## Stores

| Store | Where | Deleted by |
| --- | --- | --- |
| Restoration token (session, passphrase, directory paths, pusher id) | Keychain, `KeychainController` | `removeRestorationTokenForUsername`, `removeAllRestorationTokens` |
| Session directories: state store, **crypto store**, event cache | `SessionDirectories` under the shared container | `SessionDirectories.delete()`, `UserSessionStore.reset()` |

## Every deletion path, and its trigger

| # | Path | Trigger | Token | Directories | Verdict |
| --- | --- | --- | --- | --- | --- |
| 1 | `UserSessionStore.logout` | Sign-out | removed | deleted | User action. |
| 2 | `UserSessionStore.reset` via `AppCoordinator.wipeUserData` | First launch with no `lastVersionLaunched`, taken as "the app was deleted and reinstalled" | all removed | all deleted | Not a user action, but a fresh install by construction: the keychain outlives an uninstall and would otherwise resurrect a stranger's account on a resold phone. Kept. |
| 3 | `UserSessionStore.restoreUserSession` on failure | **Any** error restoring the first stored session | removed | deleted | **Was the defect; changed here.** A store the SDK could not open, a transport not yet up, a late keychain read: all deleted the crypto store. It now deletes only when the crypto store is already missing (`isNonTransientUserDataValid()` false, the device-transfer case upstream wrote this for). Everything else keeps the token and directories and reports the failure, so the next launch retries. `UserSessionStoreTests.restoreWhenClientCreationFails` pins the new behaviour on the files. |
| 4 | `KeychainController.restorationTokenForUsername` | Decoding a token that still names a sliding-sync proxy | removed | kept | Permanent format retirement; nothing transient reaches it. A generic decode error keeps the token. |
| 5 | `AuthenticationService.rotateSessionDirectory` | Every `makeClient` for a new homeserver during login | none | deletes the previous **attempt's** directories | Safe here, unlike the Android fork: `AppCoordinator` creates a fresh `AuthenticationService` per authentication flow, so the directories of a session already handed to the store are never the ones rotated over. Worth keeping true. |
| 6 | `SessionDirectories.deleteTransientUserData` | Cache clearing | kept | state and event cache only, crypto store kept | By design. |

## What a failed restore now looks like

`AppCoordinator` receives `.failedRestoringSession`, shows the login error
toast and the login screen. The token is still in the keychain, so
`hasSessions` stays true and the next launch tries the restore again; a
new login for the same user overwrites the token and orphans the old
directories on disk rather than deleting them. That is a worse screen than
an explicit "your account could not be restored, its data is kept" state,
which the account coordinator the architecture proposes should own, but it
no longer costs anyone their keys.

## Notifications

`NotificationServiceExtension` resolves the account by the pusher client
identifier stored in the token, bails out to the unmodified content when no
token matches, and falls back to the generic "received while offline"
notification when it cannot decrypt. No path in the extension mutates the
keychain or a directory.

## Still open

- The fork has no account coordinator, no active-account selection and no
  account-scoped reset; `restoreUserSession` still restores only the first
  token. That is the architecture's I2 work and needs the signed-device
  build it is gated on.
- The `neutrino-embed` branch (NeutrinoKit package, `NeutrinoNodeService`,
  a simulator build workflow) is the mesh spike and is not merged; its node
  storage is outside the session directories, so nothing in this table
  reaches it.
