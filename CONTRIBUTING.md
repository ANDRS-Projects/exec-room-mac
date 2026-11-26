# Contributing to Exec Room for Mac

This repository holds the Mac app around [Exec Room](https://github.com/ANDRS-Projects/exec-room)
and the scripts that build it. Changes to the room itself (its page, its server, its agents) belong
in the Exec Room repository.

## Bug reports and ideas

Open an issue. For a problem with the app, say which macOS version and which Mac you use, which
version of the app, and what you did before it happened. For a security problem, see
[SECURITY.md](SECURITY.md) instead.

## Pull requests

Keep a pull request to one change, and say in its description what it changes and how you checked
it. Every pull request runs the checks below; it is only merged once they pass.

- **Gitleaks**: no secrets in the change or its history.
- **Trivy**: no known critical vulnerability in what the repository contains.
- **CLA**: everyone who contributed has signed the agreement (below).

## License and Contributor Agreement

Exec Room is licensed under the AGPL-3.0, with a commercial license offered alongside it (see the
[README](README.md#license)). To make that possible, contributions are accepted under the
[Contributor License Agreement](CLA.md) (CLA).

ANDRS currently earns from services around Exec Room, such as installation, team setup, maintenance
and workshops, and does not charge a fee for the software itself. That can change: the agreement
allows ANDRS to license Exec Room commercially, including for a fee. Contributors are not paid in
either case.

You sign once, in your first pull request:

1. Read [CLA.md](CLA.md).
   If your employer, a client or your university owns what you write, read section 4 of the
   agreement first; an organisation can sign for its people by writing to legal@andrs.nu.
2. In the same pull request as your change, add one line at the end of
   [CLA-SIGNATURES.md](CLA-SIGNATURES.md), with your GitHub username and today's date, exactly in
   this form:

   ```
   - @your-username, YYYY-MM-DD: I have read the Contributor License Agreement (version 1) and I agree to it.
   ```

3. The **CLA** check on the pull request passes. Later pull requests don't ask again, unless the
   agreement gets a new version; everyone then signs the new version in the same way.

What the check looks at:

- **Only your own line.** Add your signature and nothing else to that file; don't change or remove
  other lines. Nobody can sign for someone else.
- **Every commit author.** If the pull request has commits by someone else, that person must have
  signed before, in a pull request of their own.
- **A linked email.** Commit with an email address that is linked to your GitHub account, or the
  check can't tell who the author is.

A pull request is only merged once the CLA check passes.

### Privacy: your signature is public

**Who is responsible.** ANDRS Projects Europe B.V., Castricum, the Netherlands (KVK 54057655), is
the controller. Contact: legal@andrs.nu. Our general terms and privacy information are at
<https://andrs-projects.notion.site/data-security-and-legal>.

**What is recorded.** The line you add to `CLA-SIGNATURES.md`: your GitHub username, the date and
the version of the agreement you agreed to. As with any contribution, git and GitHub also record
the author name and email address of your commits, the time, and the pull request.

**Why, and on what basis.** To have a record of who agreed to which version of the agreement, so
that ANDRS, and everyone who gets Exec Room from ANDRS, can rely on the licenses you gave. The
legal basis is the agreement between you and ANDRS (article 6(1)(b) GDPR) and ANDRS's legitimate
interest in being able to show that it may license Exec Room (article 6(1)(f) GDPR). You are not
obliged to sign, but we cannot accept a contribution without it.

**It is public and it stays in the history.** The repository is public, so anyone in the world can
see your line. It is hosted by GitHub, in the United States among other places, and it is copied
into every clone and fork, which ANDRS does not control. Removing a line from the file does not
remove it from the git history.

**How long.** For as long as Exec Room, or any software ANDRS licenses, contains your
contribution, and after that for as long as legal claims about it are still possible. That is why
we cannot simply delete a signature on request: while your contribution is in use, the record is
needed to establish and defend the licenses (article 17(3)(e) GDPR).

**Your rights.** You can ask ANDRS for access to your data, for a correction (for example after
you rename your GitHub account; we add a note and do not rewrite the history), and for erasure or
restriction, and you can object to the processing. We will look at every request, within the
limits explained above. You can also complain to the Dutch data protection authority, the
Autoriteit Persoonsgegevens (autoriteitpersoonsgegevens.nl).

If you prefer that your commits do not show your personal email address, use GitHub's no-reply
address before you commit.

