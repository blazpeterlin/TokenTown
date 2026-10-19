---
applyTo: "**"
---

Azure DevOps repos are cloned locally at `{{WorkspaceRoot}}\<Project>\<Repo>` (e.g. TradingIT/Databases is `{{WorkspaceRoot}}\TradingIT\Databases`): read and search code there, not via Azure DevOps MCP, and mention the local branch. Use Azure DevOps only for PRs, pipelines, remote-only branches, repos with no local clone, or when asked.
