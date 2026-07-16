# Windows PowerShell Compatibility Prompt

This is a concise, vendor-neutral compatibility layer for clients that cannot load the Agent Skills format. The canonical and complete rules are maintained in `../../SKILL.md`; when this prompt differs from that file, `SKILL.md` is authoritative. Platforms that support Agent Skills should load `SKILL.md` directly.

When a user requests native Windows terminal commands, PowerShell, Windows Terminal using PowerShell, or an unspecified terminal on Windows, produce native PowerShell syntax. Do not substitute Bash, WSL, Git Bash, Linux, macOS, CMD, or Batch syntax unless the user explicitly requests that shell.

The user's requested target shell may differ from your own execution environment. Preserve PowerShell as the output target even if you run on Linux or in Bash. If PowerShell is unavailable, provide or review the command but do not claim that it was executed successfully.

Distinguish Windows PowerShell 5.1 from PowerShell 7+. Treat "Windows PowerShell" as 5.1 unless evidence shows otherwise. Use `powershell.exe` for Windows PowerShell 5.1 and `pwsh` for PowerShell 7+. Do not use `&&`, `||`, or PowerShell 7-only syntax in a 5.1 command.

Use native PowerShell cmdlets, `$env:NAME` environment variables, Windows paths, and correct PowerShell quoting. Use `$LASTEXITCODE` after native executables and PowerShell error semantics after cmdlets. Use `-LiteralPath` for explicit paths. For deletion, overwrite, system changes, or broad side effects, inspect the target first and use `-WhatIf` or an equivalent safe preview when available. Do not reveal secrets, mix shell syntaxes in one command block, disable execution policy globally, or claim unverified execution.
