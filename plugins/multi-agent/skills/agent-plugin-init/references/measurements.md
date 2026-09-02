# Measurements

Taken 2026-09 against Claude Code (bundled version), Codex CLI 0.152.1, and Agent Plugins 1.0.

**Every conclusion in SKILL.md rests on these.** When a spec version or a tool version changes,
re-run them before trusting the guidance — and update SKILL.md if a result moved. That is the
maintenance path for a 2.0.

## Claude Code ignores the root `plugin.json`

The first line of `claude plugin validate` tells you which one it read:

```
standard plugin.json only : Validating components in: <path>
.claude-plugin/ present   : Validating plugin manifest: <path>/.claude-plugin/plugin.json
```

A standard-only plugin still loads as long as `skills/` is present, because Claude Code's manifest
is documented as optional when components sit in their default locations. But the manifest is not
read at all: with `name` set to `multi-agent` inside a directory called `t1`, the skill appeared as
`t1:agents-init`. The name comes from the directory. `version` and `displayName` never arrive.

A plugin with no manifest whatsoever also loaded.

## Selection is by extension; contents are not validated

Three files placed in a plugin-root `agents/`:

| File | Result |
|---|---|
| `reviewer.md` (Claude Code format) | registered as `<plugin>:reviewer` |
| `gemini-style.yaml` (different extension) | ignored |
| `broken.md` (no frontmatter, foreign format) | registered as `<plugin>:broken` |

`validate` warns about the third and passes anyway. A file belonging to another tool gets absorbed
whenever the extension matches.

## `skills/<name>/agents/openai.yaml` does not affect Claude Code

Claude Code looks at `skills/*/SKILL.md` and at the **plugin-root** `agents/`. A directory nested
inside a skill is not on that path. The measured subagent list contained no `openai` entry.

## Appearing in a catalog is not the same as loading

A plugin carrying only the standard `plugin.json` did show up under `codex plugin list`. That only
proves the catalog entry points at the directory. Codex names component paths in its manifest rather
than discovering them, so whether the skills actually load is a separate question — one that only
installing the plugin answers. It was not installed, so this was left unverified and the
documentation was followed instead.

## A vanished source directory fails quietly

Deleting the directory behind a locally-referenced plugin did not raise an error — the plugin simply
stopped being listed. Through a marketplace, the load error shows up in the `/plugin` Errors tab.

Moving the repository has the same effect, since the path changes. Re-registering fixes it.

## Published examples

**Google — ChromeDevTools/chrome-devtools-mcp** — root holds `plugin.json`, `.claude-plugin/` and
`.cursor-plugin/`, and no `.codex-plugin/`.

**This was misread once.** The missing `.codex-plugin/` was taken as "Codex needs no manifest of its
own", which is wrong — Codex documents `.codex-plugin/plugin.json` as required. That repository
simply does not target Codex. Presence of a file is evidence about a tool; absence is not.

**GitHub — github/awesome-copilot** — `plugins/<name>/plugin.json` only. Being Copilot-facing, it
needs no Claude Code manifest.

**OpenAI's Codex plugins** (as loaded by Codex CLI 0.152.1) — still on `.codex-plugin/plugin.json`
despite the version being newer than the 0.147.0 that added standard support, and pairing it with
`skills/<name>/agents/openai.yaml`. Recognising the standard and shipping in it are separate things.
