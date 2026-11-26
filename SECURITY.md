# Exec Room for Mac — Security Policy

## What this repository covers

The Mac app around Exec Room and the scripts that build, sign and notarise it. The room itself, its
agents and their rules are covered by
[Exec Room's security policy](https://github.com/ANDRS-Projects/exec-room/blob/main/SECURITY.md);
the app does not change them.

## Rules for this repository

- **No credentials in the repository.** The Apple signing certificate and the notarisation
  password live only in this repository's GitHub Actions secrets, and only the release workflow
  reads them. Workflows that run on pull requests never get them.
- **What the app contains is pinned.** The build uses a fixed Node.js release from nodejs.org and
  a fixed Exec Room release, each checked against its published checksum.
- **The app starts nothing in the background.** Quitting it stops the room and every agent run.

## Reporting a vulnerability

If you discover a security issue, please report it privately through GitHub's **Report a
vulnerability** button on this repository's Security tab, rather than opening a public issue.
