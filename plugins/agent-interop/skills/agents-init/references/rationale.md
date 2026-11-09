# Why the content goes in AGENTS.md

## Most of it is not Claude Code specific

What you want to write into CLAUDE.md — build and test commands, coding conventions, directory
layout, places not to touch — is exactly what you also want Codex, GitHub Copilot and others to
read. Those tools look at AGENTS.md.

Writing it into CLAUDE.md starts a second copy of the same content, and one of the two goes stale.
Pinning the content to AGENTS.md means that when another agent shows up, the only thing that grows
is the number of pointer files.

## Why keep the pointer now that Claude Code reads AGENTS.md

Claude Code reads AGENTS.md directly, but by default only when there is no `CLAUDE.md`,
`.claude/CLAUDE.md` or `CLAUDE.local.md` in the working directory or any directory above it. The
official docs list the gaps that remain:

- Adding a `CLAUDE.local.md` for personal notes, or having a `CLAUDE.md` in a parent directory,
  makes Claude read that instead, and AGENTS.md silently drops out.
- Some sessions cannot read AGENTS.md directly: the built-in `agents-md` plugin disabled, older
  versions, and in some cases the first session after an upgrade.
- An AGENTS.md read directly does not fire `InstructionsLoaded` hooks, and does not load from
  directories added with `--add-dir`.

A CLAUDE.md containing only `@AGENTS.md` closes all of these. The docs also state that keeping the
import never makes Claude read AGENTS.md twice. It costs one line, so it is the default.

AGENTS.md alone is still a legitimate choice for someone who wants a single file and accepts the
gaps above — hence the opt-in option in SKILL.md.

## Exceptions cannot be untangled later

Deciding at creation time that "this item is Claude Code specific" usually turns out wrong, because
at that point you do not yet have the evidence about what other agents need.

Adding a Claude-specific section later is easy. Separating content that got mixed together is
tedious, so in practice it never happens.

## History

- Originally, Claude Code read only CLAUDE.md, and the docs told repositories using AGENTS.md to
  add a CLAUDE.md that imports it. The pointer was then the only way to load AGENTS.md at all.
- Claude Code v2.1.277 started reading AGENTS.md directly when no CLAUDE.md exists. The pointer
  stayed as the default because it closes the gaps listed above; "AGENTS.md only" was added as an
  opt-in option.
