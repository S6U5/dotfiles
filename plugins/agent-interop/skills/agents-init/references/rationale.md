# Why the content goes in AGENTS.md

## Most of it is not Claude Code specific

What you want to write into CLAUDE.md — build and test commands, coding conventions, directory
layout, places not to touch — is exactly what you also want Codex, GitHub Copilot and others to
read. Those tools look at AGENTS.md.

Writing it into CLAUDE.md starts a second copy of the same content, and one of the two goes stale.
Pinning the content to AGENTS.md means that when another agent shows up, the only thing that grows
is the number of pointer files.

## The official docs describe this exact shape

Claude Code's documentation states "Claude Code reads `CLAUDE.md`, not `AGENTS.md`." and then tells
repositories that use AGENTS.md to add a CLAUDE.md that imports it. So a one-line `@AGENTS.md` file
is not a local invention — it is the documented answer.

## Exceptions cannot be untangled later

Deciding at creation time that "this item is Claude Code specific" usually turns out wrong, because
at that point you do not yet have the evidence about what other agents need.

Adding a Claude-specific section later is easy. Separating content that got mixed together is
tedious, so in practice it never happens.
