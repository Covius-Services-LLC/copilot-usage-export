# Copilot Usage Export Script

## Setup

Copy `Export-CopilotUsage.ps1` into your `$HOME\.copilot\` directory:

```
%USERPROFILE%\.copilot\Export-CopilotUsage.ps1
```

## Quick Start

### Export all sessions to CSV:
```powershell
powershell -ExecutionPolicy Bypass -NoProfile -Command "& '$HOME\.copilot\Export-CopilotUsage.ps1'"
```

### Export last N sessions only:
```powershell
powershell -ExecutionPolicy Bypass -NoProfile -Command "& '$HOME\.copilot\Export-CopilotUsage.ps1' -Last 10"
```

### Export to a custom output path:
```powershell
powershell -ExecutionPolicy Bypass -NoProfile -Command "& '$HOME\.copilot\Export-CopilotUsage.ps1' -OutputPath 'C:\Reports\copilot-usage.csv'"
```

## Output Location
By default: `$HOME\.copilot\copilot-usage.csv`

## What Gets Captured

### ✅ IDE Sessions (VSCode, Visual Studio)
- All IDE-based Copilot interactions
- Repository context (GitHub, Azure DevOps)
- Full event logging
- Usage metrics (AI Credits estimate, premium requests)

### ✅ CLI/Direct Copilot App
- Direct Copilot application usage
- Generic working directory context
- Full event logging
- Usage metrics

### ❌ GitHub Website
- **NOT captured** in this directory
- GitHub web interactions use separate telemetry endpoints

## CSV Columns
- `SessionId`: Unique session identifier
- `StartDateUtc`: Session start date in UTC (yyyy-MM-dd format)
- `StartTimeUtc`: Session start time in UTC (HH:mm:ss format)
- `EndDateUtc`: Last event date in UTC (yyyy-MM-dd format)
- `EndTimeUtc`: Last event time in UTC (HH:mm:ss format)
- `Repository`: Repo name (if applicable)
- `Branch`: Git branch (if applicable)
- `RepoLocation`: Translated repository host (`GitHub` or `Azure DevOps`)
- `ClientName`: Client recorded in `workspace.yaml` (for example, `vscode`, `github/cli`, or `github/autopilot`)
- `InitialModel`: Model selected at session start
- `Models`: All models used in session
- `UserMessages`: Number of user inputs/messages
- `AssistantTurns`: Number of assistant responses
- `OutputTokens`: Logged output tokens (exact)
- `UsageCheckpoints`: Usage event count
- `LastCheckpointUtc`: Timestamp of last usage checkpoint
- `TotalNanoAiu`: Raw nano-AIU counter
- `AiCreditsEstimate`: Estimated AI Credits (totalNanoAiu / 1,000,000,000)
- `UsdCost`: USD cost estimate (AiCreditsEstimate / 100, at $1.00 per 100 credits)
- `TotalPremiumRequests`: Premium request count
- `ParseErrors`: JSON parsing errors in log

`RepoLocation` identifies the repository hosting service, not whether the session came from an IDE or CLI/App. The available event logs currently identify the producer as `copilot-agent`, so they do not expose a reliable IDE-versus-CLI field.

`ClientName` is read from the session's adjacent `workspace.yaml` when available. It is useful for comparing client populations, but the exporter preserves the recorded values rather than translating them into an IDE-versus-CLI classification.

## Notes
- Usage checkpoints available from Copilot v1.0.73+ (July 23, 2026)
- Older sessions show output tokens but no credit estimates
- The CSV is idempotent—re-running updates only changed sessions
