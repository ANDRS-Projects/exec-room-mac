# Exec Room for Mac

A Mac app for [Exec Room](https://github.com/ANDRS-Projects/exec-room): install it and start your
room from the Dock or the menu bar, without a terminal.

**Status: in development. There is no download yet.** Until there is, install Exec Room from its
own repository.

## What it will be

- A small menu-bar app with **Open Exec Room** and **Quit**. Quit stops the room and every agent
  run; nothing keeps running after you quit.
- It carries its own copy of Node.js and a fixed release of Exec Room, so you don't need Homebrew
  or a terminal.
- The room opens in your own browser, as it does today.
- It does **not** include Claude Code. You install Claude Code and sign in to your own Claude plan;
  the app checks for it and helps you sign in.
- Signed and notarised by Apple, for Macs with Apple silicon.

The room itself, its agents and its security rules are those of Exec Room. This repository holds
only the app around it and the scripts that build it.

## License

AGPL-3.0-only, the same as Exec Room, with a commercial license offered alongside it: see
[LICENSE](LICENSE).
