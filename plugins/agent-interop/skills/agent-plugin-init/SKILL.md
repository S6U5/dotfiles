---
name: agent-plugin-init
description: Create an agent plugin that reaches Claude Code, Codex and the Agent Plugins standard (agent-plugins.org), deciding what can be shared and where the tool-specific parts have to go. Use this for any new skill or plugin meant for more than one coding agent — "新しいスキルを作りたい", "プラグインを追加して", "create a skill for this", "make this work in Codex too" — and equally when extending or migrating an existing one, as in "add a hook to this plugin", "bundle an MCP server", "両方のツールで使えるようにして". Deciding what goes where is the substance of the task, so trigger even when the user just says "create a skill" without mentioning portability, since choosing the wrong location silently limits it to one tool. Skip it for plugins that are deliberately single-tool, or when only the prose inside an existing SKILL.md is being edited.
---

# Deciding what to share across agent plugin formats

## Two standards, and two tools that sit outside them

- **Agent Skills** (agentskills.io) covers a single skill: `SKILL.md` is required, and client-specific settings are meant to live in **sidecar files** (Codex's `agents/openai.yaml` is one).
- **Agent Plugins 1.0** (agent-plugins.org) covers packaging: `plugin.json`, `skills/`, `mcp.json`, `com.<reverse-domain>/`.

Hooks, agents and rules fall outside both. Each tool decides those alone.

**Neither Claude Code nor Codex reads the root `plugin.json`** — the two most likely targets are the two that sit outside the standard they helped write. Claude Code reads `.claude-plugin/plugin.json`; Codex requires `.codex-plugin/plugin.json` and, unlike Claude Code, does **not** discover `skills/` by convention, so the manifest has to name the path. Cursor and Copilot/VS Code do read the root manifest, which is why it still earns its place.

So `skills/` is the only genuinely shared thing, and manifests are written once per tool.

## The shape that reaches every tool

```
plugins/<name>/
├── plugin.json                    ← standard: Cursor, Copilot/VS Code (confirmed); other conformant clients
├── .claude-plugin/plugin.json     ← Claude Code
├── .codex-plugin/plugin.json      ← Codex; needs "skills": "./skills/" spelled out
├── README.md
└── skills/<skill>/
    ├── SKILL.md                   ← the single real artifact; every tool reads this file
    └── agents/openai.yaml         ← Codex / ChatGPT UI metadata (optional)
```

Three manifests is not duplication — each is read by a different tool, and collapsing any two silently drops that tool's metadata. **Keep `name`, `version` and `description` in step across all three.**

**The condition is keeping the payload inside `skills/`.** Hold that, and new tools become reachable without restructuring.

## Creating one from scratch

1. Pick a name — check it against built-in commands and existing skills before anything else.
2. Lay out the shape above.
3. Write the three manifests, keeping `name`, `version` and `description` identical.
4. Write `skills/<skill>/SKILL.md`. Every "when to use" cue belongs in the `description` — the body is only read *after* the skill has fired, so a "When to use this skill" section in it can never influence whether it fires. Add `agents/openai.yaml` if Codex presentation matters.
5. Add an entry to each catalog the plugin should appear in.
6. Verify (below) before calling it done.

Everything below is the reasoning behind those steps — read it when a decision is not obvious.

## Deciding where something goes

Work down the list; do not drop to a lower level while a higher one still works.

**1. Ask whether `skills/` can express it.** This is the one layer every tool reads from the same file. Most urges to add a hook, a command, or a dedicated agent are satisfied by the `description` and the body instead. "Always lint after editing" genuinely needs a hook; "how to run the linter and when it matters" is just a skill. Separate *enforcement* from *instruction*.

**2. Check whether the standard manifest holds it.** `plugin.json` is `additionalProperties: false`. Required: `$schema`, `name` (lowercase alphanumerics, dots, hyphens; 1–64 chars). Optional: `version`, `description`, `author`, `homepage`, `repository`, `license`, `keywords`, `extensions`. Anything else goes under `extensions`, keyed by reverse domain.

**3. Drop it into a tool-specific location** — paired with the decision not to list the plugin in the other tools' catalogs. And do not put `.md` there (below). This level is where portability stops, so treat reaching it as a signal to re-check step 1. `references/tool-differences.md` has the per-tool detail.

## Principles

### Fewer files — or fewer words — is not the goal

Decide by **whether anything reads it**. A file nothing reads is noise; a file something reads but you removed is a feature that silently disappeared. Tidying three manifests into one produces the second case: the count drops, a tool stops receiving its metadata, nothing improved. **Reduction has no value on its own.** Left intact, the structure explains itself — each manifest names the tool that reads it.

The same holds inside a SKILL.md. Enumerating options a model already knows, or writing "each diagram" rather than "a diagram", reads as padding — yet removing exactly that measurably cut the variety and the number of diagrams one skill produced. **Knowing something and recalling it in the moment are different.** Trim prose only against a measurement, never on the assumption that the model already knows.

### Absence is not evidence

Another repository having a file tells you a tool needs it. That file being **missing tells you nothing** — the plugin may simply not target that tool. Concluding "Codex needs no manifest of its own" because Google's `chrome-devtools-mcp` ships no `.codex-plugin/` was exactly this mistake; Codex requires it. Presence is evidence, absence is not.

The same trap appears in tooling output: a plugin listed by `codex plugin list` only proves the catalog points at it. Whether its skills load is a separate question, and only installing it answers that.

### No `.md` outside what the standards cover

**Do not create `agents/`.** Same for `commands/` and `rules/`. A subagent placed there reaches Claude Code only: Codex cannot register agents bundled in a plugin at all, and its own format is TOML rather than Markdown, so there is no single file that serves both. Tools also select files in these directories by extension without validating contents, so a foreign `.md` gets adopted silently while `validate` only warns. Express the behaviour as a skill instead; if it genuinely needs enforcement, keep the definition in `com.<reverse-domain>/` and document the manual install.

### One tool passing is not passing

Frontmatter is **YAML**, not free text, and a long `description` is the easiest place to break it: a plain scalar containing `: ` is a parse error. Claude Code accepts it — `claude plugin validate` reports success and the plugin installs — while Codex's validator rejects the file outright. This skill's own frontmatter shipped broken that way, through a marketplace, unnoticed. **Run every target tool's validator, and treat a green from one as saying nothing about the others.**

Frontmatter keys differ too. Codex reads `name`, `description` and `metadata`; Claude Code additionally honours `license`, `version`, `allowed-tools`, `user-invocable`, `argument-hint` and `disable-model-invocation`. Extra keys are ignored rather than fatal, so the risk is a setting that silently does nothing — except `disable-model-invocation`, which Codex requires to be absent or `false` in a bundled plugin.

### Split by what you would turn off

Group a plugin around **what gets disabled together**. Plugin-provided skills can only be disabled *per plugin* — "Plugin skills are not affected by `skillOverrides`" — so splitting wrong means silencing one unwanted skill takes down the wanted ones beside it.

## Verify instead of assuming

Specs and implementations drift, and reading only the spec buys duplicate maintenance you did not need.

```sh
claude plugin validate ./plugins/<name>
# "Validating plugin manifest: ..." → the manifest is being read
# "Validating components in: ..."   → it is not (only skills/ is being seen)

# Codex ships its own validator inside its bundled plugin-creator skill, and it is
# the stricter of the two — manifest fields, agents/openai.yaml, and frontmatter.
python3 ~/.codex/skills/.system/plugin-creator/scripts/validate_plugin.py ./plugins/<name>

claude --plugin-dir ./plugins/<name> -p "list the available skill names"
# A name different from the manifest's `name` means that manifest was not read
```

Both must pass. See `references/measurements.md` for where each tool keeps its own field
definitions on disk — reachable and current, so neither the manifests nor `agents/openai.yaml`
need to be guessed at.

Plugin and skill names become slash commands, so avoid colliding with built-ins. Overriding is only documented for bundled skills; nothing says a custom skill can take over something like `/init`.

**When a spec or tool version changes, re-run the checks in `references/measurements.md` before trusting anything here.** Every conclusion above rests on them, and that file records when and against what versions they were taken.

## Migrating an existing plugin

Same decisions in reverse. Measure first, then compare against the current layout: a manifest nothing reads is dead weight, a manifest a tool now expects is a gap. Change one thing at a time and re-check.

## Keep personal context out

A SKILL.md is a prompt, so the author's situation leaks in easily — real project names, paths, employer — usually inside a sentence written as "a helpful concrete example". Re-read the whole file before committing to a public repository: hooks and gitleaks catch credential patterns only.

---

**Do not read these during normal work.** Everything needed to decide is above.

- `references/tool-differences.md` — per-tool layout table, where names collide, `openai.yaml` and hooks in detail. Open it when **adding support for a new tool** or when **you suspect a collision**.
- `references/measurements.md` — the measurements behind the claims above, with dates and versions. Open it when **the approach is challenged** or when **a version changed and you need to re-measure**.
