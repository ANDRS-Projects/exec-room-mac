# Exec Room for Mac

A Mac app for [Exec Room](https://github.com/ANDRS-Projects/exec-room): install it and start your
room from the Dock or the menu bar, without a terminal.

**Status: in development. There is no download yet.** Until there is, install Exec Room from its
own repository. You can build the app yourself (see Building it).

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

The app is written to `build/Exec Room.app` (about 120 MB), signed only for your own Mac.
`exec-room.ref` pins the app's version, the Exec Room commit and the Node.js version; the script
refuses a Node that isn't the official build or isn't that version.

## License

AGPL-3.0-only, the same as Exec Room, with a commercial license offered alongside it: see
[LICENSE](LICENSE).
