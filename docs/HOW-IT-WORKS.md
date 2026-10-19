# How this setup works (for LLMs)

Human quick start: `README.md`. `Setup.ps1` installs the files in this repo into a Copilot CLI profile (`-TargetDirectory`, default `$env:COPILOT_HOME` or `$HOME\.copilot`).

## Behavior

- Writes only managed files; each changed existing file is first backed up to `<target>\setup-backups\<timestamp>`. Matching files are left untouched.
- Invalid JSON aborts before any write. JSONC settings are accepted but rewritten as plain JSON (comments survive only in the backup). A failed write is not rolled back; restore from the backup.
- `-WhatIf` previews; `-Check` fails if the profile has drifted.
- Never alters ACLs, elevates, or bypasses organization policy. Humans run it from their own terminal.

## Managed files

| Source | Installed as |
| --- | --- |
| `settings.json` | Each top-level key in the template (`defaultPermissionMode`, `sandbox`) replaces the profile's key; other keys are kept. |
| `mcp-config.json` | Each server entry (`azure-devops`) replaces the same-named profile entry entirely (no merge); other servers are kept. |
| `skills\*` | Every skill folder, including supporting files. |
| `instructions\*.instructions.md` | All three: local repos, logging, git. `{{WorkspaceRoot}}` in local-repos is replaced with `-WorkspaceRoot`. |
| (generated) | `config.json`: appends `D:\GeniRepos` to `trustedFolders` if missing; nothing else changes. |

Extra files already in the profile are never deleted.

## Settings

- `defaultPermissionMode: allow-all` (same as `/yolo`, `/allow-all`).
- Sandbox: enabled, `allowBypass: false` (no manual override outside the sandbox), current directory included, MCP/LSP not sandboxed, dev tool access allowed, git/gh auth forwarding off, outbound network on, local network off.
- Read/write: `<target>\session-state` (resolved by Setup from the template placeholder) and `-WorkspaceRoot` (default `D:\GeniRepos`) only if that directory exists.
- Read-only: `-ReadOnlyRoots` (default `C:\`, `D:\`). The workspace's drive root must be included, otherwise sandboxed PowerShell fails with `InitializeDefaultDrives ... failed`.
- No credential env-var injection; any existing one in the `sandbox` section is dropped.
- Because `allow-all` is on, the sandbox is the main safety boundary.

## Instructions

- **local-repos**: Azure DevOps repos are cloned at `<WorkspaceRoot>\<Project>\<Repo>`; read them locally and mention the local branch. Use Azure DevOps only for PRs, pipelines, remote-only branches, missing clones, or when asked.
- **logging**: pass the exception when logging Serilog errors/warnings (`Log.Error(ex, msg)`, `Log.Warning(ex, msg)`).
- **git**: never stage, commit, or push; the user does it manually.

## Skills

`domain-modeling`, `grill-me`, `grill-with-docs`, `grilling`, `openapi-client`, `unprompted-unit-testing` (puts unrequested tests in a `Trash tests` subfolder and tells the user to delete or promote them).

## MCP servers

- `azure-devops`: `npx -y @azure-devops/mcp GeniDevOps` (stdio), allowlisted to 15 read-oriented tools; `pipelines_write` is excluded. The allowlist is client-side only; use a read-scoped account for real enforcement. The npm package is unpinned and may change on launch.
- Setup never starts servers or handles sign-in; the user connects via `/mcp`. Project-level MCP definitions can override same-named global servers.
- Add servers to `mcp-config.json` and rerun Setup. Never put secrets in it.
