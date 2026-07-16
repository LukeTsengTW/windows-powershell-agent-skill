# Native Windows PowerShell Instructions

This file is a compact compatibility adapter derived from the canonical `SKILL.md` in the upstream `windows-powershell-agent-skill` repository. In the original repository layout, developers can find that file at `../../SKILL.md`; that relative path is not expected to remain valid after this adapter is copied into another project.

The copied adapter contains the minimum rules required to operate independently when the upstream repository is unavailable. The upstream `SKILL.md` remains authoritative for maintenance, updates, and the complete rule set.

Apply these instructions when a task targets native Windows PowerShell, Windows Terminal using PowerShell, or an otherwise unspecified native Windows terminal. If the user explicitly requests WSL, Git Bash, Linux, macOS, CMD, or Batch, use that requested shell instead.

Essential rules:

- Default native Windows terminal commands to PowerShell. Do not output Bash, WSL, Git Bash, or CMD syntax without a shell-specific reason.
- The requested target shell may differ from the agent's execution environment. Preserve PowerShell output even if the agent runs elsewhere, and never claim a command was executed when PowerShell was unavailable.
- Distinguish Windows PowerShell 5.1 (`powershell.exe`) from PowerShell 7+ (`pwsh`). Do not use `&&`, `||`, or other PowerShell 7-only syntax for Windows PowerShell 5.1.
- Use native PowerShell cmdlets, `$env:NAME` environment variables, Windows paths, and PowerShell quoting. Do not mix shell syntaxes in one command block.
- Use `$LASTEXITCODE` after native executables. Use PowerShell success and error-handling semantics for cmdlets.
- Quote paths correctly and use `-LiteralPath` for explicit paths, especially paths containing wildcard characters.
- Before deletion, overwrite, system-setting changes, or similarly destructive work, inspect the target and use a safe preview such as `-WhatIf` when supported.
- Do not expose secrets, disable execution policy globally, use `Invoke-Expression`, or silently broaden the requested operation.

When maintaining this adapter in the upstream repository, compare it with the canonical `SKILL.md` for the complete encoding, quoting, environment-variable, native-argument, and safety rules. Do not require a copied adapter's target project to contain the upstream file.
