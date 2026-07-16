# Windows PowerShell Agent Skill

## Overview

A portable Agent Skill for generating, reviewing, converting, and executing safe native Windows PowerShell commands across AI coding agents.

This repository provides behavioral instructions for AI agents. It is not a PowerShell module, a Windows Terminal theme, or a PowerShell profile. `SKILL.md` is the canonical and complete source of the core rules. Files under `agents/` and `adapters/` provide only platform-specific metadata or thin compatibility layers.

## Why This Skill Exists

Terminal advice often assumes Bash even when a task targets native Windows. That can produce invalid commands, incorrect path syntax, unsafe deletion patterns, or behavior that changes between Windows PowerShell 5.1 and PowerShell 7+. This skill gives an agent explicit rules for selecting the requested shell and producing native PowerShell without silently switching to WSL, Git Bash, CMD, or Linux syntax.

The target shell requested by a user may differ from the agent's own execution environment. An agent running on Linux should still return PowerShell when PowerShell is the requested target, and it must not claim that a command ran successfully if PowerShell was unavailable for verification.

## Key Features

- Native PowerShell equivalents for common Bash commands and workflows.
- Explicit separation of PowerShell, CMD, WSL, Git Bash, Linux, and macOS requests.
- Compatibility rules for Windows PowerShell 5.1 and PowerShell 7+.
- Guidance for paths, quoting, environment variables, native CLI arguments, exit status, and output encoding.
- Safe preview and confirmation patterns for destructive filesystem operations.
- Thin adapters for clients that do not directly load Agent Skills.
- A dependency-free, Windows PowerShell 5.1-compatible installer.

## Supported Environments

The core guidance targets native Windows PowerShell environments:

- Windows PowerShell 5.1, launched with `powershell.exe`.
- PowerShell 7+, launched with `pwsh`.
- Windows Terminal, Visual Studio Code terminals, and AI coding agent terminals when their active or requested shell is PowerShell.

The repository is compatible with clients that can load Markdown instructions or an Agent Skills directory. Actual Agent Skills discovery, precedence, and activation behavior depend on each client. This project does not claim that every listed client implements the same skill-loading protocol.

## Repository Structure

```text
.
|-- SKILL.md                         # Canonical PowerShell behavior rules
|-- README.md                        # Project and installation documentation
|-- LICENSE                          # MIT License
|-- CHANGELOG.md                     # Version history
|-- agents/
|   `-- openai.yaml                  # OpenAI/Codex display metadata only
|-- adapters/
|   |-- github-copilot/
|   |   `-- AGENTS.md                # Thin GitHub Copilot adapter
|   `-- generic/
|       `-- SYSTEM_PROMPT.md         # Vendor-neutral compatibility prompt
|-- scripts/
|   `-- install.ps1                  # Local, dependency-free installer
`-- tests/
    |-- trigger-prompts.md           # Manual activation test prompts
    `-- expected-behavior.md         # Behavior acceptance cases
```

`adapters/` exists for platforms that cannot directly load the Agent Skills format. Adapters intentionally do not duplicate the full rule set.

## Installation

Run installation commands from the repository root. The installer reads only local repository files, does not download packages, does not require administrator rights, and does not change the execution policy.

If Windows has marked the downloaded script as blocked, inspect it first and then unblock only that file:

```powershell
Get-Content -LiteralPath ".\scripts\install.ps1"
Unblock-File -LiteralPath ".\scripts\install.ps1"
```

After installation, restart the client or open a new agent session so the skill can be discovered.

### Shared Agent Skills Directory

Install to `~/.agents/skills/windows-powershell-terminal/` for clients that scan the shared Agent Skills directory:

```powershell
powershell.exe -NoProfile -File ".\scripts\install.ps1" -Target Shared
```

From PowerShell 7+, the equivalent launcher is:

```powershell
pwsh -NoProfile -File ".\scripts\install.ps1" -Target Shared
```

### Codex

The Codex target intentionally installs to the shared Agent Skills directory, `~/.agents/skills/windows-powershell-terminal/`, rather than assuming a legacy client-specific directory:

```powershell
powershell.exe -NoProfile -File ".\scripts\install.ps1" -Target Codex
```

Whether and when that directory is discovered depends on the installed Codex client version and configuration.

### Gemini CLI

Install to `~/.gemini/skills/windows-powershell-terminal/`:

```powershell
powershell.exe -NoProfile -File ".\scripts\install.ps1" -Target Gemini
```

Gemini CLI compatibility depends on the client's current support for loading skill-style Markdown instructions.

### Claude Code

Install to `~/.claude/skills/windows-powershell-terminal/`:

```powershell
powershell.exe -NoProfile -File ".\scripts\install.ps1" -Target Claude
```

Claude Code compatibility depends on the client's current skill discovery and configuration behavior.

### GitHub Copilot

GitHub Copilot uses the thin adapter rather than a skill directory. Copy `adapters/github-copilot/AGENTS.md` to the appropriate location in a target project, or manually merge its essential rules into an existing `AGENTS.md`.

For a project that does not already contain `AGENTS.md`:

```powershell
powershell.exe -NoProfile -File ".\scripts\install.ps1" -Target Copilot -ProjectPath "C:\path\to\project"
```

The installer refuses to overwrite a different existing `AGENTS.md`. Manual merging is required because the installer cannot safely infer an existing file's structure or precedence rules.

### Generic Agents

For a client that accepts a system prompt but does not load Agent Skills, use `adapters/generic/SYSTEM_PROMPT.md` as a compact compatibility layer. If the client can load Agent Skills, load `SKILL.md` directly instead.

## Usage Examples

Prompts that should activate the skill include:

```text
Convert rm -rf node_modules to native Windows PowerShell.
Fix this command for Windows PowerShell 5.1.
Write UTF-8 without BOM from Windows PowerShell 5.1.
Run npm install and run npm test only if installation succeeds.
```

If a user explicitly asks for WSL, Git Bash, Linux, macOS, or CMD/Batch syntax, the agent should honor that shell instead of applying PowerShell conversion rules.

## PowerShell Version Behavior

When a user says "Windows PowerShell," the skill assumes Windows PowerShell 5.1 unless version information proves otherwise. Windows PowerShell 5.1 uses `powershell.exe`. PowerShell 7+ uses `pwsh`.

The pipeline-chain operators `&&` and `||` are available in PowerShell 7+ but are not valid in Windows PowerShell 5.1. For 5.1, use separate statements and explicit success checks such as `$LASTEXITCODE` after native executables or PowerShell error handling for cmdlets.

## Safety Principles

- Inspect and resolve explicit paths before destructive operations.
- Use `-LiteralPath` when a path is a literal value, especially when it contains wildcard characters such as `[` or `]`.
- Preview supported destructive commands with `-WhatIf` and remove the preview only after confirming intent and target.
- Do not expose secrets in output, source control, or command history.
- Do not disable script execution policy globally; prefer process scope or `Unblock-File` for a reviewed file.
- Do not claim successful execution when the required PowerShell runtime was unavailable.

The complete safety rules are maintained only in `SKILL.md`.

## Testing

This repository uses manual, client-neutral behavior tests:

- `tests/trigger-prompts.md` checks activation, shell selection, version assumptions, and safety expectations.
- `tests/expected-behavior.md` checks required and forbidden response characteristics.

Validate `scripts/install.ps1` with the Windows PowerShell 5.1 parser before release. A PowerShell 7 parser check is useful in addition, but it is not evidence of Windows PowerShell 5.1 runtime compatibility.

## Contributing

Keep `SKILL.md` as the single canonical source for core behavior. Changes to adapters should remain small and should not create a second copy of the full rules. Preserve Windows PowerShell 5.1 compatibility in scripts, add or update behavior cases for rule changes, and avoid new runtime or module dependencies.

## License

This project is available under the MIT License. See `LICENSE`.
