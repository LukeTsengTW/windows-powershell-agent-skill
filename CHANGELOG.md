# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Added a Skills CLI quick-start installation command to the README.
- Added `-SkillsPath` for custom skill locations and isolated installer validation without changing the user's home directory.
- Added dependency-free installer and executable-documentation regression tests, with Windows PowerShell 5.1 and PowerShell 7 CI jobs.

### Fixed

- Reject destination file/directory conflicts and installer-owned symbolic links before copying, preventing misplaced Copilot adapters and predictable partial Shared/Codex updates.
- Resolve .NET output paths relative to PowerShell's current location instead of the process working directory.
- Replace the unsafe `.gitignore` append example with Git's effective ignore check, including guidance for missing newlines, negations, and already tracked `.env` files.
- Clarify `touch` timestamp semantics, PowerShell 7.3 native argument handling, and PowerShell 7.4 byte-preserving native output redirection.
- Inspect execution policies before changing them and remove process-wide `Bypass` as the default recommendation.

## [1.0.0] - 2026-07-16

### Added

- Initial public release.
- Native Windows PowerShell command guidance.
- Windows PowerShell 5.1 and PowerShell 7+ compatibility rules.
- Bash-to-PowerShell conversion guidance.
- Safe filesystem operation rules.
- Text and output encoding guidance.
- Cross-agent compatibility adapters.
- Idempotent local installation script.
- Trigger and behavior test cases.

### Fixed

- Made copied Copilot and generic adapters independent of runtime access to the upstream repository.
- Prevented Gemini and Claude installations from receiving OpenAI-specific metadata.
- Clarified filesystem-based Skill installation behavior across compatible clients.
- Added preflight validation to prevent predictable partial Shared or Codex installations when required OpenAI metadata is unavailable.
