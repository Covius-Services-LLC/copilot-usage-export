#Requires -Version 5.1

[CmdletBinding()]
param(
    [string]$SourceRoot = (Join-Path $HOME '.copilot\session-state'),
    [string]$OutputPath = (Join-Path $HOME '.copilot\copilot-usage.csv'),
    [ValidateRange(1, [int]::MaxValue)]
    [int]$Last
)

$ErrorActionPreference = 'Stop'
$invariantCulture = [System.Globalization.CultureInfo]::InvariantCulture

function Convert-HostType {
    param([string]$HostType)

    switch ($HostType.ToLowerInvariant()) {
        'ado' { return 'Azure DevOps' }
        'github' { return 'GitHub' }
        default { return $HostType }
    }
}

if (-not (Test-Path -LiteralPath $SourceRoot -PathType Container)) {
    throw "Session-state directory not found: $SourceRoot"
}

$outputDirectory = Split-Path -Parent $OutputPath
if ($outputDirectory -and -not (Test-Path -LiteralPath $outputDirectory)) {
    New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
}

$rows = [System.Collections.Generic.List[object]]::new()
$eventFiles = @(Get-ChildItem -LiteralPath $SourceRoot -Filter 'events.jsonl' -File -Recurse)
if ($PSBoundParameters.ContainsKey('Last')) {
    $eventFiles = @($eventFiles | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First $Last)
}

foreach ($eventFile in $eventFiles) {
    $sessionId = $eventFile.Directory.Name
    $startDateUtc = $null
    $startTimeUtc = $null
    $endDateUtc = $null
    $endTimeUtc = $null
    $repository = $null
    $branch = $null
    $hostType = $null
    $initialModel = $null
    $latestCheckpoint = $null
    $latestCheckpointTimeUtc = $null
    $checkpointCount = 0
    $assistantTurns = 0
    $userMessages = 0
    $parseErrors = 0
    $models = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $outputTokensByMessage = @{}

    foreach ($line in [System.IO.File]::ReadLines($eventFile.FullName)) {
        if ([string]::IsNullOrWhiteSpace($line)) {
            continue
        }

        try {
            $event = $line | ConvertFrom-Json
        }
        catch {
            $parseErrors++
            continue
        }

        if ($event.timestamp) {
            $eventTime = ([datetimeoffset]$event.timestamp).UtcDateTime
            $endDateUtc = $eventTime.ToString('yyyy-MM-dd', $invariantCulture)
            $endTimeUtc = $eventTime.ToString('HH:mm:ss', $invariantCulture)
        }

        if ($event.data.context.hostType) {
            $hostType = Convert-HostType ([string]$event.data.context.hostType)
        }

        switch ($event.type) {
            'session.start' {
                if ($event.data.sessionId) {
                    $sessionId = [string]$event.data.sessionId
                }
                if ($event.data.startTime) {
                    $startTime = ([datetimeoffset]$event.data.startTime).UtcDateTime
                    $startDateUtc = $startTime.ToString('yyyy-MM-dd', $invariantCulture)
                    $startTimeUtc = $startTime.ToString('HH:mm:ss', $invariantCulture)
                }
                $repository = [string]$event.data.context.repository
                $branch = [string]$event.data.context.branch
                $initialModel = [string]$event.data.selectedModel
                if ($initialModel) {
                    [void]$models.Add($initialModel)
                }
            }
            'assistant.message' {
                $messageModel = [string]$event.data.model
                if ($messageModel) {
                    [void]$models.Add($messageModel)
                }

                if ($null -ne $event.data.outputTokens -and "$($event.data.outputTokens)" -match '^\d+$') {
                    $messageKey = if ($event.data.messageId) { [string]$event.data.messageId } else { [string]$event.id }
                    $outputTokens = [long]$event.data.outputTokens
                    if (-not $outputTokensByMessage.ContainsKey($messageKey) -or $outputTokens -gt $outputTokensByMessage[$messageKey]) {
                        $outputTokensByMessage[$messageKey] = $outputTokens
                    }
                }
            }
            'assistant.turn_end' {
                $assistantTurns++
                $turnModel = [string]$event.data.model
                if ($turnModel) {
                    [void]$models.Add($turnModel)
                }
            }
            'user.message' {
                $userMessages++
            }
            'session.usage_checkpoint' {
                $latestCheckpoint = $event.data
                $latestCheckpointTimeUtc = ([datetimeoffset]$event.timestamp).UtcDateTime.ToString('yyyy-MM-dd HH:mm:ss', $invariantCulture) + 'Z'
                $checkpointCount++
            }
        }
    }

    $totalOutputTokens = [long]0
    foreach ($tokenCount in $outputTokensByMessage.Values) {
        $totalOutputTokens += [long]$tokenCount
    }

    $nanoAiu = $null
    $aiCreditsEstimate = $null
    $usdCost = $null
    $premiumRequests = $null
    if ($null -ne $latestCheckpoint) {
        $nanoAiuValue = [decimal]$latestCheckpoint.totalNanoAiu
        $nanoAiu = $nanoAiuValue.ToString('0', $invariantCulture)
        $aiCreditsEstimate = ($nanoAiuValue / [decimal]1000000000).ToString('0.000000000', $invariantCulture)
        $usdCost = ($aiCreditsEstimate / [decimal]100).ToString('0.00', $invariantCulture)
        $premiumRequests = ([decimal]$latestCheckpoint.totalPremiumRequests).ToString('0', $invariantCulture)
    }

    $rows.Add([PSCustomObject][ordered]@{
        SessionId               = $sessionId
        StartDateUtc             = $startDateUtc
        StartTimeUtc             = $startTimeUtc
        EndDateUtc               = $endDateUtc
        EndTimeUtc               = $endTimeUtc
        Repository               = $repository
        Branch                   = $branch
        HostType                 = $hostType
        InitialModel             = $initialModel
        Models                   = (($models | Sort-Object) -join ';')
        UserMessages             = $userMessages
        AssistantTurns           = $assistantTurns
        OutputTokens             = $totalOutputTokens
        UsageCheckpoints         = $checkpointCount
        LastCheckpointUtc        = $latestCheckpointTimeUtc
        TotalNanoAiu             = $nanoAiu
        AiCreditsEstimate        = $aiCreditsEstimate
        UsdCost                  = $usdCost
        TotalPremiumRequests     = $premiumRequests
        ParseErrors              = $parseErrors
        SourceFile               = $eventFile.FullName
    })
}

$temporaryPath = "$OutputPath.tmp"
$rows |
    Sort-Object StartDateUtc, StartTimeUtc, SessionId |
    Export-Csv -LiteralPath $temporaryPath -NoTypeInformation -Encoding UTF8
if (Test-Path -LiteralPath $OutputPath) {
    Remove-Item -LiteralPath $OutputPath -Force
}
Move-Item -LiteralPath $temporaryPath -Destination $OutputPath -Force

$usageRows = @($rows | Where-Object { $null -ne $_.AiCreditsEstimate })
$aiCreditsTotal = [decimal]0
$premiumRequestsTotal = [decimal]0
$outputTokensTotal = [long]0
foreach ($row in $usageRows) {
    $aiCreditsTotal += [decimal]::Parse($row.AiCreditsEstimate, $invariantCulture)
    $premiumRequestsTotal += [decimal]::Parse($row.TotalPremiumRequests, $invariantCulture)
}
foreach ($row in $rows) {
    $outputTokensTotal += [long]$row.OutputTokens
}

$usdCostTotal = ($aiCreditsTotal / [decimal]100).ToString('0.00', $invariantCulture)

[PSCustomObject]@{
    OutputPath            = $OutputPath
    Sessions              = $rows.Count
    SessionsWithUsage     = $usageRows.Count
    AiCreditsEstimate     = $aiCreditsTotal.ToString('0.000000000', $invariantCulture)
    UsdCostEstimate       = "`$$usdCostTotal"
    PremiumRequests       = $premiumRequestsTotal.ToString('0', $invariantCulture)
    LoggedOutputTokens    = $outputTokensTotal
}