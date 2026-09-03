# Per-tool differences

Read when adding support for a new tool, or when you suspect a name collision.

## Layout by tool

| | Agent Plugins standard | Claude Code | Codex | Gemini CLI |
|---|---|---|---|---|
| Manifest | `plugin.json` | `.claude-plugin/plugin.json` | `.codex-plugin/plugin.json` | `plugin.json` (required marker) |
| Skills | `skills/` | `skills/` (by convention) | path named in the manifest | `skills/` |
| MCP | `mcp.json` | `.mcp.json` | `mcpServers` in the manifest | `mcp_config.json` |
| Hooks | (not covered) | `hooks/hooks.json` | `hooks/hooks.json` (auto-detected) | `hooks.json` |
| Agents | (not covered) | `agents/*.md` | `~/.codex/agents/*.toml`, **not loadable from a plugin** | `agents/` (subagent templates) |
| Rules | (not covered) | `.claude/rules/` | — | `rules/` |

**Codex does not discover components by convention.** Its manifest names the paths:
`"skills": "./skills/"`, `"mcpServers": "./.mcp.json"`, `"hooks": "./hooks/hooks.json"`. Paths are
relative to the plugin root and start with `./`. The one exception is hooks: a file at the default
`./hooks/hooks.json` is picked up without an entry.

Neither Claude Code nor Codex reads the root `plugin.json`, so a plugin targeting both plus the
standard carries three manifests.

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
| Copilot / VS Code | yes | documented layout uses the root manifest plus `com.github.copilot/` |
| Claude Code | no | measured |
| Codex | no | documented: `.codex-plugin/plugin.json` is required |
| Kiro, Gemini, ChatGPT | unverified | listed as launch clients; not checked directly |

Cursor also has its own `.cursor-plugin/plugin.json`, but that is for Cursor-specific components
(rules, agents, commands, hooks, variables, its own `mcpServers` shape) — not a sign that the root
manifest is ignored. Google's `chrome-devtools-mcp` ships both for exactly that reason.

## How each tool finds a plugin

| Tool | Discovery |
|---|---|
| Claude Code | catalog at `.claude-plugin/marketplace.json`, then `plugin install` |
| Codex | repo catalog at `$REPO_ROOT/.agents/plugins/marketplace.json` (personal: `~/.agents/plugins/marketplace.json`), then `plugin add` |
| Cursor | **no catalog** — reads whatever sits in `~/.cursor/plugins/local/`, so a symlink is the install step |

A root `plugin.json` therefore earns its place even with no catalog entry pointing at it: Cursor
picks it up straight from that directory. Reload the window after linking.

## Subagents cannot be shipped to both

Claude Code loads `agents/*.md` from the plugin root. Codex uses TOML in `~/.codex/agents/` or
`<project>/.codex/agents/`, with `name` / `description` / `developer_instructions` required and
`sandbox_mode = "read-only"` available — **and it cannot register agents bundled in a plugin**
(openai/codex#18988). The documented workaround is to ship the `.toml` and tell the user to copy or
symlink it into their agents directory.

So there is no file that serves both, and one of the two tools always needs a manual step. Put the
behaviour in a skill unless enforcement (tool restrictions, a separate context) is the actual
requirement. If it is, keep the Codex definition under `com.openai.codex/` — the reverse-domain
namespace the standard reserves for client-specific components — so it is already in the right place
if Codex gains bundle support.

Note that Claude Code ignores `hooks`, `mcpServers` and `permissionMode` inside a plugin-provided
subagent for security reasons.

## Where names collide

`agents/` — Claude Code and Gemini CLI use the same directory for different things. The word also
appears in `agents/openai.yaml` inside a skill (Codex's sidecar), so `agents` names three unrelated
concepts.

`plugin.json` — Gemini treats it as a required package marker, a role separate from the standard's.

MCP — four incompatible shapes across the standard, Claude Code, Codex and Gemini. They also tend to
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

Gemini CLI ships a `~/.agents/skills/` alias and states the reason as interoperability between AI
tools. Codex uses `.agents/plugins/marketplace.json` for its catalog. `.agents/` is settling in as
the neutral location.
