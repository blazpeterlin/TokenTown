# Windows Copilot setup

Sandboxed, `allow-all` Copilot CLI profile with Azure DevOps MCP, skills, and instructions.

## Requirements

Windows, PowerShell 7, Node.js (`npx`), Copilot CLI (signed in, closed during setup).

## Install

```powershell
pwsh -ExecutionPolicy Bypass -File .\Setup.ps1
```

Then restart Copilot CLI and make sure you made a /login .

Options: `-TargetDirectory`, `-WorkspaceRoot`, `-ReadOnlyRoots`.

Details for agents: [docs/HOW-IT-WORKS.md](docs/HOW-IT-WORKS.md).
