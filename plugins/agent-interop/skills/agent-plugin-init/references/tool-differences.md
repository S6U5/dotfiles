# Per-tool differences

Read when adding support for a new tool, or when you suspect a name collision.

## Layout by tool

| | Agent Plugins standard | Claude Code | Codex | Antigravity |
|---|---|---|---|---|
| Manifest | `plugin.json` | `.claude-plugin/plugin.json` | root `plugin.json` first (with an agent-plugins.org `$schema`), `.codex-plugin/plugin.json` on top for `interface` / `apps` / `hooks`; without a root manifest, `.codex-plugin/` → `.claude-plugin/` → `.cursor-plugin/` | `plugin.json` (only `name` required) |
| Skills | `skills/` | `skills/` (by convention) | `skills/` by default; a `skills` path in the manifest replaces it | `skills/` |
| MCP | `mcp.json` | `.mcp.json` | `mcp.json` under a root manifest; otherwise `mcpServers` in the manifest, defaulting to `.mcp.json` | packaged; shape unchecked |
| Hooks | (not covered) | `hooks/hooks.json` | `hooks/hooks.json` (auto-detected) | packaged; shape unchecked |
| Agents | (not covered) | `agents/*.md` | `~/.codex/agents/*.toml`, **not loadable from a plugin** | CLI only; shape unchecked |
| Rules | (not covered) | `.claude/rules/` | — | packaged; shape unchecked |

Gemini CLI is no longer listed: Google stopped serving it for free and Google AI Pro / Ultra use on
2026-06-18 and moved those users to Antigravity CLI (`agy`), a separate rewrite. Its layout does not
carry over, so do not target it.

**Codex discovers the default locations too.** With no `skills` entry it scans `skills/`, with no
`mcpServers` entry it reads `.mcp.json`, and `hooks/hooks.json` is picked up without an entry. A
manifest entry such as `"skills": "./skills/"` is still accepted (OpenAI's own scaffold writes it);
for skills it replaces the default rather than adding to it. Paths are relative to the plugin root
and start with `./`. (Source: `codex-rs/core-plugins/src/loader.rs`, `plugin_skill_roots` and the
`DEFAULT_*` constants, unchanged from 0.152.1 to the 2026-10 main branch.)

**Which manifest Codex reads.** `find_plugin_manifest_path` in `codex-rs/utils/plugins` takes the
root `plugin.json` when its `$schema` is an agent-plugins.org URL; otherwise it falls back to
`.codex-plugin/plugin.json`, then `.claude-plugin/plugin.json`, then `.cursor-plugin/plugin.json`.
Under a root manifest, Codex takes `name` / `version` / `description` / `keywords` from it, fixes
skills at `./skills` and MCP at `./mcp.json`, and then applies Codex-specific data from
`extensions["com.openai"]` in the root manifest — or, when that is absent, from
`.codex-plugin/plugin.json`. Only `interface`, `apps`, `hooks` and the onboarding skill come from that
overlay; its `name`, `version` and `skills` are ignored. Without an `interface` there, the UI falls back
to the plugin `name` as the display name and category `Other`.

So a plugin targeting Claude Code, Codex and the standard still carries three manifests, for
different reasons: Claude Code reads only its own; the standard needs the root one; and
`.codex-plugin/plugin.json` carries Codex's presentation (and is the whole manifest for Codex
before 0.147.0, or if the root manifest is ever dropped). Moving the `interface` block into
`extensions["com.openai"]` makes the third file unnecessary for current Codex, at the cost of older
versions.

The root `$schema` has to be exactly the 1.0.0 identifier: Codex rejects any other agent-plugins.org
version (the 1.1.0 draft included), and treats a symlinked `plugin.json` as no manifest at all.

## Hooks work in both, with one incompatibility

Event names (`PostToolUse`, `SessionStart`, …) and the `matcher` / `hooks[].type` / `command`
schema are shared, so a `hooks.json` largely transfers. Two things do not:

- **Plugin root variable** — Codex uses `${PLUGIN_ROOT}`, Claude Code uses `${CLAUDE_PLUGIN_ROOT}`.
  A hook that only runs a shell command is unaffected; one that calls a script inside the plugin is.
- **Tool names in matchers** — Codex's canonical write tool is `apply_patch`, with `Write` / `Edit`
  as aliases. A matcher of `Write|apply_patch` hits both hosts.

The standard says nothing about hooks, so this compatibility is incidental and can drift.

## Who actually reads the root `plugin.json`

| Tool | Reads it | How this was established |
|---|---|---|
| Cursor | yes | documented: "a plugin that follows the Agent Plugins specification loads in Cursor without changes" |
| Copilot CLI | yes | documented: root `plugin.json` is searched first, ahead of `.github/plugin/` and `.claude-plugin/` |
| VS Code | yes | documented: a `$schema` pointing at Agent Plugins 1.0 selects that format; `.claude-plugin/plugin.json` is also detected |
| Antigravity | yes | measured: the standard manifest, extra fields included, passes `agy plugin validate` and its skills load |
| Claude Code | no | measured |
| Codex | **yes, first** (0.147.0+) | source: root manifest wins when its `$schema` is agent-plugins.org; `.codex-plugin/plugin.json` becomes an overlay for `interface` / `apps` / `hooks`. OpenAI's build guide still describes `.codex-plugin/plugin.json` as the required manifest |
| Kiro, ChatGPT | unverified | listed as launch clients; not checked directly |

Cursor also has its own `.cursor-plugin/plugin.json`, but that is for Cursor-specific components
(rules, agents, commands, hooks, variables, its own `mcpServers` shape) — not a sign that the root
manifest is ignored. Google's `chrome-devtools-mcp` ships both for exactly that reason.

## How each tool finds a plugin

| Tool | Discovery |
|---|---|
| Claude Code | catalog at `.claude-plugin/marketplace.json`, then `plugin install` |
| Codex | repo catalog at `$REPO_ROOT/.agents/plugins/marketplace.json` (personal: `~/.agents/plugins/marketplace.json`), then `plugin add`. Without one it also reads `.claude-plugin/marketplace.json` and `.cursor-plugin/marketplace.json`, in that order |
| Cursor | **no catalog** — reads whatever sits in `~/.cursor/plugins/local/`, so a symlink is the install step |
| Copilot CLI | catalog at `marketplace.json`, `.plugin/`, `.github/plugin/` or **`.claude-plugin/marketplace.json`** (searched in that order), so Claude Code's catalog serves it unchanged; `plugin install` **copies** into `~/.copilot/installed-plugins/<marketplace>/<name>/`, so follow edits with `plugin update` |
| VS Code | picks up everything Copilot CLI installed; a local directory can also be registered in the `chat.pluginLocations` setting |
| Antigravity | **no catalog** — reads `~/.gemini/config/plugins/` (shared by Antigravity, its CLI and IDE). `agy plugin install <path>` **copies**, so edits stop reaching it; a symlink keeps them live (measured) |

A root `plugin.json` therefore earns its place even with no catalog entry pointing at it: Cursor
picks it up straight from that directory. Reload the window after linking.

## Repo-committed auto-loading of a bundled plugin (documented 2026-10-23)

Discovery (above) is one question; whether a file **committed in the repo** auto-enables a
repo-bundled plugin for anyone who clones it — with no per-user install — is another. The table
below is **documentation-based, not re-measured**; trust and headless rows are marked where the docs
are silent.

| Tool | Committed config auto-enables a bundled plugin? | Key file(s) | Trust gate | Headless (`-p`/CI) |
|---|---|---|---|---|
| Claude Code | yes | `.claude/settings.json` — `enabledPlugins` + `extraKnownMarketplaces` (directory source) | required | no |
| Codex | partial — `[plugins."x@mkt"] enabled = true` + marketplace `INSTALLED_BY_DEFAULT`; "clone-only, no approval" is not documented | `.codex/config.toml` + `$REPO_ROOT/.agents/plugins/marketplace.json` | yes — trusted project; bundled hooks are reviewed before running | unconfirmed (`codex exec` unstated) |
| GitHub Copilot | yes — the nearest match to Claude Code; also reads `.claude-plugin/marketplace.json`; the cloud agent's official distribution path | `.github/copilot/settings.json` — `enabledPlugins` + `extraKnownMarketplaces` | "trusted working directory" concept exists; enable-time prompt unconfirmed | unconfirmed (auto-update skipped in CI) |
| Cursor | no — plugins load from `~/.cursor/plugins/local/` or the marketplace; rules/skills are the committed path instead | `.cursor/rules/*.mdc`, `.cursor/skills` or `.agents/skills` | Enterprise "Allow Local Plugin Imports" (off by default) | unconfirmed |
| Antigravity | IDE/App yes (`.agents/plugins/`, project-scoped); CLI no — manual `agy plugin install` | `<workspace>/.agents/plugins/` | unconfirmed | unconfirmed |

Two takeaways. The confirmed cross-tool path for a repo-local component is still a **skill** in
`.agents/skills/` (every tool reads it; Claude Code via the symlink). And the committed-settings
*plugin* path is **not Claude Code-only** — Copilot is near-identical (the same two keys, and it
reads `.claude-plugin/marketplace.json`), and Codex has a close equivalent. Trust gating and headless
behaviour are the shaky parts: mostly unstated upstream, so verify them on-machine before relying on
them.

Sources (official docs, read 2026-10-23): Codex — developers.openai.com/codex/skills,
developers.openai.com/plugins/build/plugins; Cursor — cursor.com/docs/plugins; Copilot CLI —
docs.github.com/en/copilot/reference/copilot-cli-reference/cli-plugin-reference and
.../concepts/agents/copilot-cli/about-cli-plugins; Antigravity — antigravity.google/docs/plugins,
antigravity.google/docs/skills. The measured probes in `measurements.md` are from 2026-09 and predate
this review; re-run them before trusting the measured rows.

## Subagents cannot be shipped to both

Claude Code loads `agents/*.md` from the plugin root. Codex uses TOML in `~/.codex/agents/` or
`<project>/.codex/agents/`, with `name` / `description` / `developer_instructions` required and
`sandbox_mode = "read-only"` available — **and it cannot register agents bundled in a plugin**
(openai/codex#18988). The documented workaround is to ship the `.toml` and tell the user to copy or
symlink it into their agents directory.

So there is no file that serves both, and one of the two tools always needs a manual step. Put the
behaviour in a skill unless enforcement (tool restrictions, a separate context) is the actual
requirement. If it is, keep the Codex definition under `com.openai/` — Codex's extension namespace
(`extensions["com.openai"]` in its loader), and the standard puts a client's files in a top-level
directory of the same name — so it is already in the right place if Codex gains bundle support.

Note that Claude Code ignores `hooks`, `mcpServers` and `permissionMode` inside a plugin-provided
subagent for security reasons.

## Where names collide

`agents/` — Claude Code and Gemini CLI used the same directory for different things (Antigravity CLI's custom agents are unchecked). The word also
appears in `agents/openai.yaml` inside a skill (Codex's sidecar), so `agents` names three unrelated
concepts.

`.agents/plugins/` — Codex reads a catalog file there, and Antigravity treats the same directory in a
workspace as a folder of plugins. A `marketplace.json` file sitting there was measured to be ignored by
Antigravity, but do not put plugin directories next to it.

MCP — incompatible shapes across the standard, Claude Code, Codex and Gemini/Antigravity. They also tend to
need API keys, which sits badly with a public repository. Keep MCP out of plugins.

Copilot isolates its components under `com.github.copilot/`, so it never collides. The problem comes
from tools that place theirs at the plugin root.

## `agents/openai.yaml` (Codex / ChatGPT)

A sidecar file, which is what the Agent Skills standard prescribes for client-specific settings.
Two roles:

**UI metadata** — `interface` with `display_name`, `short_description`, `icon_small`, `icon_large`,
`brand_color`, `default_prompt`. Manifests only carry plugin-level metadata, so per-skill
presentation can only be set here.

**Implicit invocation** — `policy.allow_implicit_invocation`. Setting it to `false` stops Codex from
firing the skill off the user's prompt while leaving `$skill` working. It is the counterpart to
Claude Code's frontmatter `disable-model-invocation: true`, which Codex cannot express in SKILL.md.
The same intent lives in two places in two forms — do not change one and leave the other behind.

**Declared dependencies** — `dependencies.tools[]`, currently only `type: "mcp"` with `value`,
`description`, `transport` and `url`. This is the one place a bundled skill may name an MCP server.

The default for implicit invocation is `true`, so omit the whole `policy` block when implicit firing
is wanted. Most of OpenAI's own plugins carry only `interface`.

The file is validated strictly: `interface`, `policy` and `dependencies` are the only top-level keys
accepted, unknown keys under them are errors, and `display_name` and `short_description` are
required once the file exists. `default_prompt` is documented as having to name the skill as
`$skill-name`, and `short_description` as 25–64 characters; neither is enforced, so both are easy to
get wrong silently.

## `SKILL.md` frontmatter: what each key reaches

The Agent Skills spec defines six fields and no more. Constraints, from the spec: `name` is 1–64
lowercase alphanumerics and hyphens, no leading/trailing/consecutive hyphens, and must match the
parent directory name; `description` is 1–1024 characters; `compatibility` is up to 500; `metadata`
is a map of string to string; `allowed-tools` is a space-separated string and is marked
experimental, so support varies by implementation.

| Key | Spec | Claude Code CLI | claude.ai upload / Skills API / `package_skill.py` | Codex |
|---|---|---|---|---|
| `name`, `description` | required | accepted | accepted | required |
| `license`, `compatibility` | optional | accepted, acts on neither | accepted | ignored |
| `metadata` | optional, free-form | free-form; acts on nothing | accepted | reads `metadata.short-description` |
| `allowed-tools` | optional, experimental | pre-approves tools for the invoking turn | accepted | ignored |
| `when_to_use`, `argument-hint`, `arguments`, `model`, `effort`, `context`, `agent`, `background`, `hooks`, `paths`, `shell`, `disallowed-tools`, `user-invocable` | – | honoured | **hard error** | ignored |
| `disable-model-invocation` | – | honoured | **hard error** | must be absent or `false` in a bundled plugin |

The failure on the third column is not a warning:

```
Unexpected key(s) in SKILL.md frontmatter: argument-hint. Allowed properties are: allowed-tools, compatibility, description, license, metadata, name
```

Claude Code's docs state the conclusion directly: restricting frontmatter to the spec's six fields
avoids that error, and Claude Code accepts all six, so spec-conformant frontmatter loads there
unchanged. **The six fields are the floor; a seventh is a deliberate trade of reach for behaviour.**

`user-invocable: false` and `disable-model-invocation: true` are opposite halves of the same
control, and Codex expresses the second through `policy.allow_implicit_invocation: false` in
`agents/openai.yaml` — inverted polarity, different file. Change one and the other stays behind.

### Two ways a key goes wrong without anyone noticing

**Same name, different meaning.** `metadata` is free-form, so nothing stops two tools from
assigning meaning to the same key. Codex already does, with `metadata.short-description`. The spec
recommends "reasonably unique" key names for this reason, and Claude Code separately warns against
reusing frontmatter field names such as `paths` as `metadata` keys.

**Right name, wrong format.** `tools` belongs to Claude Code's subagent frontmatter; the skill field
is `allowed-tools`. Two skills in the official Claude Code marketplace carry `tools:` and load
without complaint, granting nothing. Selection by extension and lenient parsing mean a key from a
neighbouring format is inert rather than rejected.

### The parsers differ in strictness, and that part does break

Claude Code accepts frontmatter that is not valid YAML — a `description` containing `: ` in a plain
scalar, for instance — and `claude plugin validate` still passes. Codex's validator rejects the
file. Parse the frontmatter yourself, or run both validators; see `measurements.md`.

## Claude Code only

Commands, LSP servers, background monitors, and the plugin's `settings.json`.

The `agent` key in `settings.json` replaces the main-thread agent outright: enabling such a plugin
changes the system prompt, tool restrictions and model for the whole session. Leave it alone.

## Neutral directory

`.agents/` is settling in as the neutral location, and by now it holds more than a catalog.

| Path | Used by |
|---|---|
| `<repo>/.agents/plugins/marketplace.json` | Codex, repo/team catalog (personal: `~/.agents/plugins/marketplace.json`) |
| `<repo>/.agents/skills/<name>/` | Codex project skills — `$CWD`, each parent, and `$REPO_ROOT` |
| `~/.agents/skills/<name>/` | Codex personal skills (Gemini CLI also read it, as an alias for interoperability) |
| `<workspace>/.agents/skills/`, `<workspace>/.agents/plugins/` | Antigravity workspace skills and plugins (reported; the plugins one collides with Codex's catalog location, see above) |

Codex also reads a repository's `.codex/skills/`, which none of its documentation mentions —
measured, so treat it as behaviour rather than a promise.

**Claude Code reads none of these.** Its skills come from `.claude/skills/` (the startup directory
and every parent up to the repo root), `~/.claude/skills/`, each `--add-dir` directory, and plugins.
Codex correspondingly does not read `.claude/skills/`.

Since both follow symlinks, a repository-local skill lives once in `.agents/skills/<name>/` with
`.claude/skills/<name>` linked at it. Claude Code documents that a target reachable from two of its
locations loads once, so the link costs nothing beyond the file. See `measurements.md` for what was
verified and what rests on documentation.
