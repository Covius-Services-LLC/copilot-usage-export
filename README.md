# Copilot Usage Export Script

## Quick Start

Clone or copy the script anywhere, then run it from the script's directory:

```powershell
# From the folder where you saved Export-CopilotUsage.ps1:
powershell -ExecutionPolicy Bypass -NoProfile -File ".\Export-CopilotUsage.ps1"
```

The script auto-detects your session-state data in this order:
1. A `session-state\` folder **beside the script** (useful if you symlink/copy to a custom location)
2. The default GitHub Copilot install at `$HOME\.copilot\session-state\`

### Export last N sessions only:
```powershell
powershell -ExecutionPolicy Bypass -NoProfile -File ".\Export-CopilotUsage.ps1" -Last 10
```

### Export to a custom output path:
```powershell
powershell -ExecutionPolicy Bypass -NoProfile -File ".\Export-CopilotUsage.ps1" -OutputPath 'C:\Reports\copilot-usage.csv'
```

### Point at a custom session-state folder:
```powershell
powershell -ExecutionPolicy Bypass -NoProfile -File ".\Export-CopilotUsage.ps1" -SourceRoot 'D:\CopilotData\session-state'
```

## Output Location
By default, the CSV is written **beside the script** as `copilot-usage.csv`.  
Override with `-OutputPath` to write anywhere.

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
- `HostType`: Translated repository host (`GitHub` or `Azure DevOps`)
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

`HostType` identifies the repository hosting service, not whether the session came from an IDE or CLI/App. The available event logs currently identify the producer as `copilot-agent`, so they do not expose a reliable IDE-versus-CLI field.

## Notes
- Usage checkpoints available from Copilot v1.0.73+ (July 23, 2026)
- Older sessions show output tokens but no credit estimates
- The CSV is idempotent—re-running updates only changed sessions
