# Exec Room for Mac

A Mac app for [Exec Room](https://github.com/ANDRS-Projects/exec-room): install it and start your
room from the Dock or the menu bar, without a terminal.

## Download

**[Download the latest version](https://github.com/ANDRS-Projects/exec-room-mac/releases/latest)**
(`Exec-Room-<version>.dmg`, about 45 MB). For Macs with Apple silicon (M1 or later), macOS 13 or later.

1. **Install Claude Code** first, if you haven't: see the
   [Claude Code docs](https://code.claude.com/docs). The app runs Claude Code; it doesn't include it.
2. **Open the downloaded file** and drag **Exec Room** onto **Applications**.
3. **Open Exec Room** from Applications. The first time, macOS asks whether to open an app downloaded
   from the internet; it names ANDRS Projects Europe B.V. as the developer and says Apple checked it.
   Click **Open**.
4. **Answer two questions:** where agents work, and whether they run on your Claude plan or on an
   Anthropic API key. The room then opens in its own window. If Claude Code isn't signed in yet, the
   page has a **Sign in to Claude** button.

The app is signed by ANDRS Projects Europe B.V. and notarised by Apple. Each release lists the
SHA-256 of its download, so you can check it with `shasum -a 256 Exec-Room-<version>.dmg`.
**Updating:** quit Exec Room, download the new version and drag it onto Applications again; your rooms, chats and
settings stay, since they live outside the app.

## What it does

- An app in the Dock and the menu bar. Starting it starts your room and opens it in its own window
  (Safari's engine, no tabs or address bar); clicking the Dock icon brings the window back. Closing
  the window leaves the room running; **Open in Browser** is in the menu. Links that leave the room
  (Connect sign-ins, Notion pages, GitHub, mail drafts) open in your browser or mail app, and a
  Connect sign-in finished there shows up in the window by itself. The same menu is in the menu bar icon, the app menu (top
  left) and on the Dock icon (right-click), since a full menu bar on a MacBook hides icons behind the
  camera notch.
- **First start** asks two things:
  1. **Where agents work.** Agents start in this folder and save their drafts in its `drafts`
     folder. Suggested: `~/Documents/Exec Room`. Every agent can read what's in it, so use a folder
     for Exec Room only. Your home folder and `~/Library` are refused.
  2. **How agents are paid for.** Your Claude plan (Claude Code's own sign-in; the room's page has
     a **Sign in to Claude** button, and the app never sees your sign-in), or an Anthropic API key,
     paid per use with a limit per run and per day. The key is kept in your Mac's Keychain and
     handed only to the agent runs.
- **The menu:** whether the room is running, **Show Room Window**, **Open in Browser**, **Show Log**, **Change Work
  Folder…**, **Pay With** (plan or key) and **Quit Exec Room**. Changing the folder or how you pay
  restarts the room and asks first, since agents that are working stop.
- **Quit stops the room and every agent run.** If the app was force-quit and left its room running,
  the next start stops that room first, so nothing keeps running unseen.
- If the room can't start (no work folder, a folder it refuses, the port in use), the app shows the
  room's own reason, and **Show Log** opens the full output.
- It carries its own Node.js (from nodejs.org) and a fixed commit of Exec Room, so you don't need
  Homebrew or a terminal. It does **not** include Claude Code: you install Claude Code yourself.
- Apple silicon only, macOS 13 or later.

The room itself, its agents and its security rules are those of Exec Room. This repository holds
only the app around it and the scripts that build it.

## Where things are

| What | Where |
|---|---|
| The room's settings and data (chats, rooms, job log) | `~/Library/Application Support/Exec Room` |
| The room's output | `~/Library/Logs/Exec Room/room.log` (the previous start's in `room.previous.log`) |
| The work folder and drafts | the folder you chose (shown in the menu) |
| The API key, if you use one | your Keychain, item "Exec Room: Anthropic API key" |
| The app's own choices | `defaults read nu.andrs.exec-room` |

The room uses port 4179, the same as Exec Room started from a clone, so only one of the two can run
at a time. To give the app another port: `defaults write nu.andrs.exec-room port 4191`. Connect
sign-ins (Notion, Resend and the like) are tied to the port they were made on.

## Building it

You need an Apple silicon Mac with Xcode's command line tools (`xcode-select --install`), an
unpacked Node.js build for Apple silicon from [nodejs.org](https://nodejs.org/en/download) at the
version in [`exec-room.ref`](exec-room.ref), and a clone of Exec Room:

```bash
NODE_DIR=~/Downloads/node-v22.23.1-darwin-arm64 EXEC_ROOM_DIR=~/exec-room scripts/build-app.sh
```

The app is written to `build/Exec Room.app` (about 120 MB), signed only for your own Mac unless
`SIGN_ID` names a Developer ID certificate (see Releasing).
`exec-room.ref` pins the app's version, the Exec Room commit and the Node.js version; the script
refuses a Node that isn't the official build or isn't that version.

## Releasing

`scripts/release.sh` builds the download: the app signed with a Developer ID and notarised by Apple,
inside a signed and notarised disk image, `dist/Exec-Room-<version>.dmg`, with its SHA-256. It needs,
once per Mac:

1. **A "Developer ID Application" certificate** in your Keychain. Only the Apple Developer account
   holder can make one: in Keychain Access, Certificate Assistant → Request a Certificate From a
   Certificate Authority (saved to disk), then upload that request at
   [developer.apple.com](https://developer.apple.com/account/resources/certificates/list) → Certificates
   → + → Developer ID Application, and open the certificate you download. If `security find-identity -v -p codesigning` doesn't list
   it as valid, Apple's in-between certificate is missing (Xcode normally installs it): import
   "Developer ID - G2" from [Apple's certificate page](https://www.apple.com/certificateauthority/).
2. **A notarisation sign-in** saved in the Keychain as `exec-room`, with an App Store Connect API key
   (Users and Access → Integrations → Team Keys, role Developer):
   `xcrun notarytool store-credentials exec-room --key <AuthKey_….p8> --key-id <key id> --issuer <issuer id>`.

Then:

```bash
SIGN_ID="Developer ID Application: <name> (<team id>)" NODE_DIR=… EXEC_ROOM_DIR=… scripts/release.sh
```

To publish it: `gh release create v<version> dist/Exec-Room-<version>.dmg dist/Exec-Room-<version>.dmg.sha256`
(with the release notes), after the version and the pinned Exec Room release in `exec-room.ref` are merged.

Apple checks every program inside; each of the two submissions (the app, then the disk image) can
take a few minutes, and a refusal prints Apple's reasons. Node is signed again with only what its
JavaScript engine needs ([`Resources/node.entitlements`](Resources/node.entitlements)): its own
signature also allows debugging, which notarisation refuses. The icon is the room's own mark
(`public/mark.svg` at the pinned commit).

## License

AGPL-3.0-only, the same as Exec Room, with a commercial license offered alongside it: see
[LICENSE](LICENSE).
