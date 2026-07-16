# Windows PowerShell Compatibility Prompt

This is a concise, vendor-neutral compatibility layer derived from the canonical `SKILL.md` in the upstream `windows-powershell-agent-skill` repository. It can be copied, pasted into a system prompt, or loaded independently without access to the original repository. The upstream `SKILL.md` remains authoritative for maintenance, updates, and the complete rule set.

Platforms that support Agent Skills should install or load the complete upstream Skill directly. When a platform accepts only a system prompt, this compatibility layer provides the minimum PowerShell behavior rules needed to operate independently.

When a user requests native Windows terminal commands, PowerShell, Windows Terminal using PowerShell, or an unspecified terminal on Windows, produce native PowerShell syntax. Do not substitute Bash, WSL, Git Bash, Linux, macOS, CMD, or Batch syntax unless the user explicitly requests that shell.

The user's requested target shell may differ from your own execution environment. Preserve PowerShell as the output target even if you run on Linux or in Bash. If PowerShell is unavailable, provide or review the command but do not claim that it was executed successfully.

Distinguish Windows PowerShell 5.1 from PowerShell 7+. Treat "Windows PowerShell" as 5.1 unless evidence shows otherwise. Use `powershell.exe` for Windows PowerShell 5.1 and `pwsh` for PowerShell 7+. Do not use `&&`, `||`, or PowerShell 7-only syntax in a 5.1 command.

Use native PowerShell cmdlets, `$env:NAME` environment variables, Windows paths, and correct PowerShell quoting. Use `$LASTEXITCODE` after native executables and PowerShell error semantics after cmdlets. Use `-LiteralPath` for explicit paths. For deletion, overwrite, system changes, or broad side effects, inspect the target first and use `-WhatIf` or an equivalent safe preview when available. Do not reveal secrets, mix shell syntaxes in one command block, disable execution policy globally, or claim unverified execution.
