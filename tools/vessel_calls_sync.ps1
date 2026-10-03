$ErrorActionPreference = "Stop"

$apiUrl =
  "https://rpt.rlisystems.ru/api/conterra/primsyb.SEAPORT/rpc/171/1710027"

$referer =
  "https://rpt.rlisystems.ru/calling/PRIMSYB"

Write-Host ""
Write-Host "Vessel Calls local sync"
Write-Host "-----------------------"
Write-Host ""

$auth = Read-Host "Paste Authorization (Basic ...)"

if ([string]::IsNullOrWhiteSpace($auth)) {
  throw "Authorization is empty."
}

function Get-VesselCallsMode {
  param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("plan", "crnt", "closed")]
    [string]$Mode
  )

  $body = @{
    input = @{
      mode = $Mode
    }
    output = @{}
  } | ConvertTo-Json -Depth 5 -Compress

  $request = [System.Net.HttpWebRequest]::Create($apiUrl)

  $request.Method = "POST"
  $request.Accept = "application/json, text/plain, */*"
  $request.ContentType = "application/json;charset=UTF-8"
  $request.Headers.Add("Authorization", $auth)
  $request.Headers.Add("Origin", "https://rpt.rlisystems.ru")
  $request.Referer = $referer

  $bodyBytes =
    [System.Text.Encoding]::UTF8.GetBytes($body)

  $request.ContentLength = $bodyBytes.Length

  $requestStream = $request.GetRequestStream()

  try {
    $requestStream.Write(
      $bodyBytes,
      0,
      $bodyBytes.Length
    )
  }
  finally {
    $requestStream.Dispose()
  }

  $response = $request.GetResponse()

  try {
    $responseStream = $response.GetResponseStream()

    try {
      $memoryStream =
        New-Object System.IO.MemoryStream

      try {
        $responseStream.CopyTo($memoryStream)

        $responseBytes =
          $memoryStream.ToArray()
      }
      finally {
        $memoryStream.Dispose()
      }
    }
    finally {
      $responseStream.Dispose()
    }
  }
  finally {
    $response.Dispose()
  }

  $responseText =
    [System.Text.Encoding]::UTF8.GetString(
      $responseBytes
    )

  $parsed =
    $responseText |
    ConvertFrom-Json

  if ($parsed.resultCode -ne 0) {
    throw "Source returned resultCode $($parsed.resultCode) for mode $Mode."
  }

  if (
    $null -eq $parsed.resultsets -or
    @($parsed.resultsets).Count -eq 0
  ) {
    return
  }

  $rows = $parsed.resultsets[0].rows

  if ($null -eq $rows) {
    return
  }

  foreach ($row in @($rows)) {
    Write-Output $row
  }
}

Write-Host ""
Write-Host "Reading plan..."
$plan = @(Get-VesselCallsMode -Mode "plan")

Write-Host "Reading crnt..."
$crnt = @(Get-VesselCallsMode -Mode "crnt")

Write-Host "Reading closed..."
$closed = @(Get-VesselCallsMode -Mode "closed")

Write-Host ""
Write-Host "Result:"
Write-Host "  plan   : $($plan.Count)"
Write-Host "  crnt   : $($crnt.Count)"
Write-Host "  closed : $($closed.Count)"

$outputDirectory =
  Join-Path $PSScriptRoot "vessel_calls_output"

if (-not (Test-Path $outputDirectory)) {
  New-Item `
    -ItemType Directory `
    -Path $outputDirectory | Out-Null
}

$timestamp =
  Get-Date -Format "yyyyMMdd_HHmmss"

$outputPath =
  Join-Path `
    $outputDirectory `
    "vessel_calls_$timestamp.json"

$payload = @{
  syncedAt = (Get-Date).ToString("o")
  plan = $plan
  crnt = $crnt
  closed = $closed
}

$json =
  $payload |
  ConvertTo-Json -Depth 20

$utf8NoBom =
  New-Object System.Text.UTF8Encoding($false)

[System.IO.File]::WriteAllText(
  $outputPath,
  $json,
  $utf8NoBom
)

Write-Host ""
Write-Host "Saved:"
Write-Host "  $outputPath"

Remove-Variable auth