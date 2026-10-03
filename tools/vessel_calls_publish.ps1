$ErrorActionPreference = "Stop"

$inputPath = $args[0]

if ([string]::IsNullOrWhiteSpace($inputPath)) {
  throw "Input JSON path is required."
}

if (-not (Test-Path $inputPath)) {
  throw "Input JSON file does not exist: $inputPath"
}

if ([string]::IsNullOrWhiteSpace($env:VESSEL_CALLS_INGEST_TOKEN)) {
  throw "Environment variable VESSEL_CALLS_INGEST_TOKEN is empty."
}

$raw =
  Get-Content `
    $inputPath `
    -Raw `
    -Encoding UTF8 |
  ConvertFrom-Json

function Parse-SourceDate {
  param(
    [Parameter(Mandatory = $false)]
    [string]$Value
  )

  if ([string]::IsNullOrWhiteSpace($Value)) {
    return $null
  }

  return [DateTime]::ParseExact(
    $Value,
    "yyyyMMdd HH:mm:ss",
    [System.Globalization.CultureInfo]::InvariantCulture
  )
}

function Get-EffectiveFrom {
  param(
    [Parameter(Mandatory = $true)]
    $Call
  )

  $actual = Parse-SourceDate $Call.calling_date

  if ($null -ne $actual) {
    return $actual
  }

  return Parse-SourceDate $Call.plan_calling_date
}

function Get-EffectiveTo {
  param(
    [Parameter(Mandatory = $true)]
    $Call
  )

  $actual = Parse-SourceDate $Call.saling_date

  if ($null -ne $actual) {
    return $actual
  }

  return Parse-SourceDate $Call.plan_saling_date
}

$callsById = @{}

foreach ($call in @($raw.plan)) {
  if ($null -ne $call) {
    $callsById["$($call.calling_id)"] = $call
  }
}

foreach ($call in @($raw.crnt)) {
  if ($null -ne $call) {
    $callsById["$($call.calling_id)"] = $call
  }
}

$preparedCalls = @()

foreach ($entry in $callsById.GetEnumerator()) {
  $call = $entry.Value

  if ($null -eq $call) {
    continue
  }

  $from = Get-EffectiveFrom $call
  $to = Get-EffectiveTo $call

  if ($null -eq $from -or $null -eq $to) {
    continue
  }

  $preparedCalls += [PSCustomObject]@{
    sourceCall = $call
    from = $from
    to = $to
  }
}

$preparedCalls =
  @(
    $preparedCalls |
    Sort-Object from
  )

if ($preparedCalls.Count -eq 0) {
  throw "No normalized vessel calls were produced."
}

$laneUntil = @(
  [DateTime]::MinValue,
  [DateTime]::MinValue,
  [DateTime]::MinValue,
  [DateTime]::MinValue
)

$normalizedCalls = @()

foreach ($prepared in $preparedCalls) {
  $selectedLane = -1

  for ($lane = 0; $lane -lt 4; $lane++) {
    if ($prepared.from -ge $laneUntil[$lane]) {
      $selectedLane = $lane
      break
    }
  }

  if ($selectedLane -lt 0) {
    $earliestLane = 0

    for ($lane = 1; $lane -lt 4; $lane++) {
      if ($laneUntil[$lane] -lt $laneUntil[$earliestLane]) {
        $earliestLane = $lane
      }
    }

    $selectedLane = $earliestLane
  }

  $laneUntil[$selectedLane] = $prepared.to

  $call = $prepared.sourceCall

  $normalizedCalls += [PSCustomObject]@{
    id = "$($call.calling_id)"
    vesselImo = "$($call.calling_id)"
    vesselName = "$($call.ship_name)"
    vesselType = "container"
    operationKind = "cargo"
    lane = $selectedLane
    berthFrom = $prepared.from.ToString("o")
    berthTo = $prepared.to.ToString("o")
    updatedAt = (Get-Date).ToString("o")
    source = "monthlySnapshot"
  }
}

$currentMonth =
  @(
    $normalizedCalls |
    Where-Object {
      $date = [DateTime]::Parse($_.berthFrom)

      $date.Year -eq 2026 -and
      $date.Month -eq 10
    }
  )

if ($currentMonth.Count -eq 0) {
  throw "No calls found for 2026-10."
}

$publishedUntil =
  $currentMonth |
  ForEach-Object {
    [DateTime]::Parse($_.berthTo)
  } |
  Sort-Object |
  Select-Object -Last 1

$now = Get-Date

$revision =
  [int64](
    [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
  )

$payload = @{
  year = 2026
  month = 10
  revision = $revision
  publishedUntil = $publishedUntil.ToString("o")
  calls = @($currentMonth)
  sourceUpdatedAt = $now.ToString("o")
  locallyUpdatedAt = $now.ToString("o")
  isArchived = $false
}

$body =
  $payload |
  ConvertTo-Json -Depth 20

$headers = @{
  Authorization = "Bearer $env:VESSEL_CALLS_INGEST_TOKEN"
}

$response = Invoke-RestMethod `
  -Uri "https://europe-west1-epistola-434b7.cloudfunctions.net/ingestVesselCallsMonth" `
  -Method Post `
  -Headers $headers `
  -ContentType "application/json;charset=UTF-8" `
  -Body $body

$response |
  ConvertTo-Json -Depth 5