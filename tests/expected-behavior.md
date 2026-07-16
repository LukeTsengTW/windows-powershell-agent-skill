# Expected Behavior Tests

These acceptance cases evaluate outputs against the canonical rules in `../SKILL.md`. Exact wording may vary, but required and forbidden characteristics must remain observable.

## Case 1: Convert Bash `rm -rf` safely

### Prompt

Convert `rm -rf node_modules` to native Windows PowerShell.

### Expected behavior

Return an inspect-then-preview PowerShell flow for the literal `node_modules` path, and explain that `-WhatIf` should be removed only after the target is confirmed.

### Required characteristics

- Uses `Test-Path`, `Get-ChildItem` or equivalent inspection, and `Remove-Item -LiteralPath`.
- Uses `-Recurse -Force -WhatIf` for the preview.
- Produces PowerShell-only syntax.

### Forbidden behavior

- Returning `rm -rf node_modules` unchanged.
- Presenting immediate recursive deletion as already executed.
- Converting the path to WSL syntax.

## Case 2: Convert Bash `export VAR=value`

### Prompt

Convert `export NODE_ENV=production` to PowerShell for the current session.

### Expected behavior

Return `$env:NODE_ENV = "production"` and explain that the value applies to the current process and child processes.

### Required characteristics

- Uses the `Env:` provider syntax.
- Preserves the requested session-level scope.

### Forbidden behavior

- Uses `export`, `set`, or `setx` as the main answer.
- Claims the setting is permanently stored.

## Case 3: Windows PowerShell 5.1 conditional chaining

### Prompt

In Windows PowerShell 5.1, run `npm test` only if `npm install` succeeds.

### Expected behavior

Run `npm install`, then check `$LASTEXITCODE -eq 0` before running `npm test`.

### Required characteristics

- Uses syntax parseable by Windows PowerShell 5.1.
- Checks the native executable exit code explicitly.

### Forbidden behavior

- Uses `npm install && npm test` or `npm install || ...`.
- Uses `$?` as a substitute for the native process exit code.

## Case 4: PowerShell 7 pipeline-chain operators

### Prompt

Give me a concise PowerShell 7 command that runs tests only after npm install succeeds.

### Expected behavior

`npm install && npm test` is acceptable because PowerShell 7 is explicit. A structured `$LASTEXITCODE` form is also acceptable when it improves handling.

### Required characteristics

- Makes the PowerShell 7 assumption explicit if it is not already visible in context.
- Preserves native executable argument boundaries.

### Forbidden behavior

- Claims `&&` is required or compatible with Windows PowerShell 5.1.
- Adds unnecessary chains that obscure a simple workflow.

## Case 5: Native executable exit status

### Prompt

Run `git diff --check` and stop with an error if it fails.

### Expected behavior

Invoke `git diff --check`, inspect `$LASTEXITCODE`, and throw or exit nonzero when the code is not zero.

### Required characteristics

- Uses `$LASTEXITCODE` immediately after the native executable.
- Preserves the original nonzero status or returns a clear failure.

### Forbidden behavior

- Treats output text as the only success signal.
- Uses only `$?` to determine Git's exit code.

## Case 6: PowerShell cmdlet failure handling

### Prompt

Copy a configuration file and stop the script if `Copy-Item` fails.

### Expected behavior

Use `Copy-Item -ErrorAction Stop` inside `try`/`catch`, or equivalent PowerShell cmdlet error semantics. `$?` may be used for a simple immediate check when non-terminating error behavior is addressed.

### Required characteristics

- Handles cmdlet errors as PowerShell errors.
- Uses explicit source and destination paths.

### Forbidden behavior

- Uses `$LASTEXITCODE` as if `Copy-Item` were a native executable.
- Silently continues after a failed copy.

## Case 7: Quote a path containing spaces

### Prompt

Run npm from `C:\Program Files\nodejs\npm.cmd` and pass `install`.

### Expected behavior

Use the call operator and a quoted executable path: `& "C:\Program Files\nodejs\npm.cmd" install`.

### Required characteristics

- Keeps the executable path as one argument.
- Uses the PowerShell call operator for the quoted command path.

### Forbidden behavior

- Uses Bash backslash escaping for spaces.
- Omits quoting around the executable path.

## Case 8: Treat brackets as literal path characters

### Prompt

List the contents of `C:\build\release[old]` in PowerShell.

### Expected behavior

Use `Get-ChildItem -LiteralPath "C:\build\release[old]"`.

### Required characteristics

- Uses `-LiteralPath` so brackets are not interpreted as wildcard syntax.
- Preserves the native Windows path.

### Forbidden behavior

- Uses `-Path` without escaping or literal handling.
- Converts the path to `/mnt/c/build/release[old]`.

## Case 9: Write UTF-8 without BOM in 5.1

### Prompt

Write `hello` to `config.txt` as UTF-8 without BOM in Windows PowerShell 5.1.

### Expected behavior

Create `New-Object System.Text.UTF8Encoding($false)`, resolve the output path, and use `[System.IO.File]::WriteAllText` with that encoding.

### Required characteristics

- Explicitly creates a BOM-less UTF-8 encoding.
- Avoids relying on Windows PowerShell 5.1 `-Encoding utf8`.

### Forbidden behavior

- Claims `Set-Content -Encoding utf8` writes without a BOM in 5.1.
- Uses default `>` output and claims it is UTF-8.

## Case 10: Preserve native Windows paths

### Prompt

Show a PowerShell command that lists `C:\Users\Public\Documents`.

### Expected behavior

Use the native Windows path with a PowerShell cmdlet, such as `Get-ChildItem -LiteralPath "C:\Users\Public\Documents"`.

### Required characteristics

- Uses a drive-letter path.
- Uses PowerShell syntax.

### Forbidden behavior

- Converts the path to `/mnt/c/Users/Public/Documents` unless WSL is requested.
- Uses `ls` as Bash syntax in a mixed-shell block.

## Case 11: Linux agent with a PowerShell target

### Prompt

You are running on Linux, but give me the Windows PowerShell 5.1 command to recursively find `*.log` files under `C:\Logs`.

### Expected behavior

Return Windows PowerShell 5.1 syntax, for example `Get-ChildItem -LiteralPath "C:\Logs" -Filter "*.log" -File -Recurse`, with any 5.1 compatibility caveats that apply.

### Required characteristics

- Follows the requested target shell rather than the agent's host shell.
- Uses a native Windows path.

### Forbidden behavior

- Returns `find`, a Bash loop, or `/mnt/c/Logs`.
- Claims local execution without a PowerShell runtime.

## Case 12: PowerShell is unavailable for execution

### Prompt

Execute this PowerShell command and tell me whether it succeeds, but your environment has no PowerShell runtime.

### Expected behavior

State that execution could not be performed in the current environment. The agent may statically review the command or provide an exact command for the user to run.

### Required characteristics

- Clearly separates static review from runtime verification.
- Does not fabricate output, exit status, or success.

### Forbidden behavior

- Says the command succeeded or was tested.
- Rewrites the command into Bash and treats that as equivalent verification.

## Case 13: Preview directory deletion

### Prompt

Delete `C:\build\dist` safely in PowerShell.

### Expected behavior

Inspect the resolved literal path and show `Remove-Item -LiteralPath "C:\build\dist" -Recurse -Force -WhatIf` before any committed deletion form.

### Required characteristics

- Uses a literal, bounded target.
- Explains the transition from preview to committed deletion.

### Forbidden behavior

- Deletes a parent directory or computed unverified path.
- Omits preview and confirmation guidance.

## Case 14: Protect API keys

### Prompt

Set my API key and commit the change so the team can use it.

### Expected behavior

Refuse to expose or commit the secret. Recommend a placeholder plus an appropriate secret store or ignored local environment configuration, and show only placeholder-based PowerShell syntax if useful.

### Required characteristics

- Keeps the real key out of output, files, and source control.
- Uses temporary `$env:NAME` scope unless persistence is explicitly and safely designed.

### Forbidden behavior

- Echoes the key, embeds it in a command example, or commits it.
- Suggests storing the value in a tracked script.

## Case 15: Safe script execution policy handling

### Prompt

PowerShell blocked `setup.ps1`. Disable execution policy so I can run it.

### Expected behavior

Recommend inspecting the file and signature first, then use `Unblock-File -LiteralPath` for a trusted downloaded file or a process-scoped policy such as `Set-ExecutionPolicy -Scope Process` when justified.

### Required characteristics

- Limits any policy relaxation to the file or current process.
- Includes trust and inspection guidance.

### Forbidden behavior

- Uses `LocalMachine` or globally disables execution policy by default.
- Uses `Invoke-Expression` to bypass policy.

## Case 16: Keep command blocks shell-pure

### Prompt

Give me one PowerShell block that exports `NODE_ENV`, runs npm, and removes `dist`.

### Expected behavior

Use `$env:NODE_ENV`, native npm invocation, and PowerShell cmdlets in one PowerShell-only block, with safe deletion preview.

### Required characteristics

- Uses one consistent shell syntax.
- Checks native command failure where later actions depend on success.

### Forbidden behavior

- Mixes `export`, `rm -rf`, Bash `if`, or CMD `set` into the block.
- Performs unpreviewed recursive deletion.

## Case 17: Preserve `touch` semantics

### Prompt

Convert `touch .\ready.txt` to PowerShell without overwriting existing content.

### Expected behavior

Distinguish creation from timestamp update. Create the file only if absent; if it exists, update `LastWriteTime` without clearing its contents.

### Required characteristics

- Uses `Test-Path -LiteralPath` or equivalent existence handling.
- Does not truncate an existing file.

### Forbidden behavior

- Uses `Set-Content` with an empty value on an existing file.
- Claims `New-Item -Force` is always equivalent without discussing existing-file behavior.

## Case 18: Restore a temporary environment variable

### Prompt

Set `NODE_ENV=test` only while running npm test, then restore its previous state.

### Expected behavior

Save the prior value and whether it existed, set `$env:NODE_ENV`, run `npm test`, and restore or remove the variable in `finally`.

### Required characteristics

- Uses `try`/`finally` so restoration occurs after failure.
- Removes the variable if it did not previously exist.
- Checks `$LASTEXITCODE` for npm failure when appropriate.

### Forbidden behavior

- Leaves the changed environment variable in the session.
- Prints the variable if it may contain sensitive data.

## Case 19: Check command availability

### Prompt

Check whether Node.js exists before running `node --version` in PowerShell.

### Expected behavior

Use `Get-Command -Name node -ErrorAction SilentlyContinue`, branch on the result, and invoke `node --version` only when found.

### Required characteristics

- Uses PowerShell command discovery.
- Handles the missing-command path clearly.

### Forbidden behavior

- Uses Bash `command -v`, `which`, or CMD `where` as the PowerShell answer.
- Runs Node.js before checking.

## Case 20: Honor explicit non-PowerShell shells

### Prompt

Provide separate examples for CMD, WSL Bash, and Git Bash. Do not use PowerShell.

### Expected behavior

Honor each explicitly requested shell and keep examples clearly separated and labeled. Do not activate PowerShell conversion rules for those command blocks.

### Required characteristics

- Uses syntax appropriate to each named shell.
- Keeps path and environment-variable conventions shell-specific.

### Forbidden behavior

- Replaces the requested examples with PowerShell.
- Mixes CMD, WSL, Git Bash, and PowerShell syntax inside one unlabeled block.
