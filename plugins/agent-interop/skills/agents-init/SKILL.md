---
name: agents-init
description: Keep CLAUDE.md a one-line `@AGENTS.md` pointer and put the actual instructions in AGENTS.md. Use this whenever agent instruction files are being created in a repo that has no CLAUDE.md yet — "CLAUDE.md を作って", "AGENTS.md を用意して", "/init して", "set up agent instructions for this repo", "write the coding conventions for Claude" — even when the user mentions only one of the two files. Claude Code reads AGENTS.md directly only when no CLAUDE.md or CLAUDE.local.md exists on the path and the session supports it, so AGENTS.md alone can silently stop loading; the pointer closes every such gap at the cost of one line. Also trigger when asked to record build steps, conventions, directory layout, or prohibitions for agents and the destination would be CLAUDE.md or AGENTS.md. When invoked explicitly, it also migrates an existing content-bearing CLAUDE.md into AGENTS.md. Do not use for merely reading these files.
---

# Instructions live in AGENTS.md; CLAUDE.md is a pointer

The end state is the same regardless of how you got here:

- `CLAUDE.md` — one line: `@AGENTS.md`
- `AGENTS.md` — the actual instructions

## Branch on how you were asked

**Asked for CLAUDE.md** — keep it to the pointer line; write the content into AGENTS.md (append if it already exists).

**Asked for AGENTS.md** — after writing it, check whether CLAUDE.md exists. If not, create it with the pointer line without asking. Claude Code can read AGENTS.md on its own, but only while no `CLAUDE.md` / `.claude/CLAUDE.md` / `CLAUDE.local.md` sits in the working directory or above it, and only in sessions where that support is available. The pointer keeps the instructions loading in every case.

**Invoked explicitly** (`/agents-init`) — branch on repo state:

- A CLAUDE.md with real content exists → move that content into AGENTS.md and reduce CLAUDE.md to the pointer. This is a migration: diff it and confirm nothing was dropped.
- Neither file exists → create an empty AGENTS.md plus the pointer CLAUDE.md, and stop. **Do not invent content.** What goes in there is the user's call.

When you trigger automatically (the user did not invoke you), limit yourself to new files and leave an existing CLAUDE.md alone.

## Option: AGENTS.md only

If the user explicitly says they want no CLAUDE.md at all, AGENTS.md alone is a valid choice: current Claude Code reads it directly. Respect that and skip the pointer, but tell them once what silently turns it off (a `CLAUDE.local.md` or an ancestor `CLAUDE.md`, an older Claude Code, or a session without AGENTS.md support). Do not offer this option unprompted — the default is the pointer.

## Notes

A symlink (`ln -s AGENTS.md CLAUDE.md`) has the same effect, but Windows requires admin rights or Developer Mode, so use the import instead.

"This item is Claude Code specific, so write it straight into CLAUDE.md" is almost always wrong at creation time — you cannot yet tell what other agents will need. Keep the pointer, and add Claude-specific content in the session where it genuinely becomes necessary.

Afterwards, tell the user that CLAUDE.md is only a pointer and the content lives in AGENTS.md. Otherwise they will not know which file to open.

---

`references/rationale.md` holds the reasoning behind this shape. **Do not read it during normal work.** Open it only when the user challenges the approach or asks why.
