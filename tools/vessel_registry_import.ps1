param(
    [Parameter(Mandatory = $false)]
    [string]$VesselInputPath = "tools\vessel_calls_output\vessel_registry_import_v2_2026-10-04.json",

    [Parameter(Mandatory = $false)]
    [string]$LineInputPath = "tools\vessel_calls_output\line_registry_import_2026-10-04.json",

    [Parameter(Mandatory = $false)]
    [string]$ProjectId = "epistola-434b7",

    [Parameter(Mandatory = $false)]
    [string]$UpdatedBy = "registry_import",

    [Parameter(Mandatory = $false)]
    [string]$AccessToken,

    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$AllowedPhysicalTypes = @(
    "container",
    "bulk",
    "reefer",
    "multipurpose",
    "generalCargo",
    "other",
    "unknown"
)

$AllowedWorkTypes = @(
    "container",
    "bulk",
    "other",
    "unknown"
)

function Get-NormalizedString {
    param(
        [Parameter(Mandatory = $false)]
        [object]$Value
    )

    if ($null -eq $Value) {
        return ""
    }

    return "$Value".Trim()
}

function Resolve-RegistryFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Registry JSON not found: $Path"
    }

    return (Resolve-Path -LiteralPath $Path).Path
}

function Read-RegistryJson {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $Raw = Get-Content `
        -LiteralPath $Path `
        -Raw `
        -Encoding UTF8

    if ([string]::IsNullOrWhiteSpace($Raw)) {
        throw "Registry JSON is empty: $Path"
    }

    $Parsed = $Raw | ConvertFrom-Json

    if ($null -eq $Parsed) {
        throw "Failed to parse registry JSON: $Path"
    }

    return @($Parsed)
}

function Assert-LineEntry {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Entry,

        [Parameter(Mandatory = $true)]
        [int]$Index
    )

    $Prefix = "Line entry #$Index"

    $DocumentId = Get-NormalizedString $Entry.documentId
    $DisplayName = Get-NormalizedString $Entry.displayName
    $DefaultWorkType = Get-NormalizedString $Entry.defaultWorkType

    if ([string]::IsNullOrWhiteSpace($DocumentId)) {
        throw "${Prefix}: documentId is missing."
    }

    if ($DocumentId.Contains("/")) {
        throw "${Prefix}: documentId contains '/': $DocumentId"
    }

    if ([string]::IsNullOrWhiteSpace($DisplayName)) {
        throw "${Prefix}: displayName is missing."
    }

    if ($Entry.schemaVersion -ne 1) {
        throw "${Prefix}: schemaVersion must be 1."
    }

    if ($DefaultWorkType -notin $AllowedWorkTypes) {
        throw "${Prefix}: unsupported defaultWorkType '$DefaultWorkType'."
    }
}

function Assert-VesselEntry {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Entry,

        [Parameter(Mandatory = $true)]
        [int]$Index
    )

    $Prefix = "Vessel entry #$Index"

    $DocumentId = Get-NormalizedString $Entry.documentId
    $Name = Get-NormalizedString $Entry.name
    $LineId = Get-NormalizedString $Entry.lineId
    $PhysicalType = Get-NormalizedString $Entry.physicalType
    $DefaultWorkType = Get-NormalizedString $Entry.defaultWorkType

    if ([string]::IsNullOrWhiteSpace($DocumentId)) {
        throw "${Prefix}: documentId is missing."
    }

    if ($DocumentId.Contains("/")) {
        throw "${Prefix}: documentId contains '/': $DocumentId"
    }

    if ([string]::IsNullOrWhiteSpace($Name)) {
        throw "${Prefix}: name is missing."
    }

    if ([string]::IsNullOrWhiteSpace($LineId)) {
        throw "${Prefix}: lineId is missing."
    }

    if ($LineId.Contains("/")) {
        throw "${Prefix}: lineId contains '/': $LineId"
    }

    if ($Entry.schemaVersion -ne 2) {
        throw "${Prefix}: schemaVersion must be 2."
    }

    if ($PhysicalType -notin $AllowedPhysicalTypes) {
        throw "${Prefix}: unsupported physicalType '$PhysicalType'."
    }

    if ($DefaultWorkType -notin $AllowedWorkTypes) {
        throw "${Prefix}: unsupported defaultWorkType '$DefaultWorkType'."
    }

    $EntryAllowedWorkTypes = @($Entry.allowedWorkTypes)

    if ($EntryAllowedWorkTypes.Count -eq 0) {
        throw "${Prefix}: allowedWorkTypes must not be empty."
    }

    foreach ($WorkType in $EntryAllowedWorkTypes) {
        $NormalizedWorkType = Get-NormalizedString $WorkType

        if ($NormalizedWorkType -notin $AllowedWorkTypes) {
            throw "${Prefix}: unsupported allowedWorkType '$NormalizedWorkType'."
        }
    }

    if ($DefaultWorkType -notin $EntryAllowedWorkTypes) {
        throw "${Prefix}: defaultWorkType is not in allowedWorkTypes."
    }

    if ($null -ne $Entry.workTypeOverride) {
        $Override = Get-NormalizedString $Entry.workTypeOverride

        if (-not [string]::IsNullOrWhiteSpace($Override)) {
            if ($Override -notin $AllowedWorkTypes) {
                throw "${Prefix}: unsupported workTypeOverride '$Override'."
            }

            if ($Override -notin $EntryAllowedWorkTypes) {
                throw "${Prefix}: workTypeOverride is not in allowedWorkTypes."
            }
        }
    }

    if ($null -ne $Entry.imo) {
        $Imo = Get-NormalizedString $Entry.imo

        if (-not [string]::IsNullOrWhiteSpace($Imo)) {
            if ($Imo -notmatch '^\d{7}$') {
                throw "${Prefix}: IMO must contain exactly 7 digits: '$Imo'."
            }
        }
    }
}

function New-FirestoreNullValue {
    return @{
        nullValue = "NULL_VALUE"
    }
}

function New-FirestoreStringValue {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Value
    )

    return @{
        stringValue = $Value
    }
}

function New-FirestoreBooleanValue {
    param(
        [Parameter(Mandatory = $true)]
        [bool]$Value
    )

    return @{
        booleanValue = $Value
    }
}

function New-FirestoreIntegerValue {
    param(
        [Parameter(Mandatory = $true)]
        [long]$Value
    )

    return @{
        integerValue = "$Value"
    }
}

function New-FirestoreDoubleValue {
    param(
        [Parameter(Mandatory = $true)]
        [double]$Value
    )

    return @{
        doubleValue = $Value
    }
}

function New-FirestoreNullableStringValue {
    param(
        [Parameter(Mandatory = $false)]
        [object]$Value
    )

    $Normalized = Get-NormalizedString $Value

    if ([string]::IsNullOrWhiteSpace($Normalized)) {
        return New-FirestoreNullValue
    }

    return New-FirestoreStringValue $Normalized
}

function New-FirestoreNullableIntegerValue {
    param(
        [Parameter(Mandatory = $false)]
        [object]$Value
    )

    if ($null -eq $Value) {
        return New-FirestoreNullValue
    }

    return New-FirestoreIntegerValue ([long]$Value)
}

function New-FirestoreNullableDoubleValue {
    param(
        [Parameter(Mandatory = $false)]
        [object]$Value
    )

    if ($null -eq $Value) {
        return New-FirestoreNullValue
    }

    return New-FirestoreDoubleValue ([double]$Value)
}

function New-FirestoreStringArrayValue {
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$Values
    )

    $Items = @()

    foreach ($Value in $Values) {
        $Items += @{
            stringValue = (Get-NormalizedString $Value)
        }
    }

    return @{
        arrayValue = @{
            values = $Items
        }
    }
}

function ConvertTo-FirestoreLineFields {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Entry,

        [Parameter(Mandatory = $true)]
        [string]$UpdatedByValue
    )

    $DisplayName = Get-NormalizedString $Entry.displayName
    $NormalizedName = Get-NormalizedString $Entry.normalizedName

    if ([string]::IsNullOrWhiteSpace($NormalizedName)) {
        $NormalizedName = $DisplayName.ToUpperInvariant()
    }

    return @{
        schemaVersion = New-FirestoreIntegerValue 1
        displayName = New-FirestoreStringValue $DisplayName
        normalizedName = New-FirestoreStringValue $NormalizedName
        defaultWorkType = New-FirestoreStringValue (
            Get-NormalizedString $Entry.defaultWorkType
        )
        isVerified = New-FirestoreBooleanValue (
            [bool]$Entry.isVerified
        )
        updatedBy = New-FirestoreStringValue $UpdatedByValue
    }
}

function ConvertTo-FirestoreVesselFields {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Entry,

        [Parameter(Mandatory = $true)]
        [string]$UpdatedByValue
    )

    $Name = Get-NormalizedString $Entry.name
    $NormalizedName = Get-NormalizedString $Entry.normalizedName

    if ([string]::IsNullOrWhiteSpace($NormalizedName)) {
        $NormalizedName = $Name.ToUpperInvariant()
    }

    return @{
        schemaVersion = New-FirestoreIntegerValue 2
        name = New-FirestoreStringValue $Name
        normalizedName = New-FirestoreStringValue $NormalizedName
        lineId = New-FirestoreStringValue (
            Get-NormalizedString $Entry.lineId
        )
        physicalType = New-FirestoreStringValue (
            Get-NormalizedString $Entry.physicalType
        )
        defaultWorkType = New-FirestoreStringValue (
            Get-NormalizedString $Entry.defaultWorkType
        )
        allowedWorkTypes = New-FirestoreStringArrayValue @(
            $Entry.allowedWorkTypes
        )
        workTypeOverride = New-FirestoreNullableStringValue (
            $Entry.workTypeOverride
        )
        workType = New-FirestoreStringValue (
            Get-NormalizedString $Entry.workType
        )
        isVerified = New-FirestoreBooleanValue (
            [bool]$Entry.isVerified
        )
        imo = New-FirestoreNullableStringValue $Entry.imo
        lengthMeters = New-FirestoreNullableDoubleValue (
            $Entry.lengthMeters
        )
        deadweightTons = New-FirestoreNullableIntegerValue (
            $Entry.deadweightTons
        )
        teuCapacity = New-FirestoreNullableIntegerValue (
            $Entry.teuCapacity
        )
        photoPath = New-FirestoreNullableStringValue (
            $Entry.photoPath
        )
        marineTrafficUrl = New-FirestoreNullableStringValue (
            $Entry.marineTrafficUrl
        )
        updatedBy = New-FirestoreStringValue $UpdatedByValue
    }
}

function New-FirestoreLineWrite {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Entry,

        [Parameter(Mandatory = $true)]
        [string]$Project,

        [Parameter(Mandatory = $true)]
        [string]$UpdatedByValue
    )

    $DocumentId = Get-NormalizedString $Entry.documentId

    $DocumentName = (
        "projects/{0}/databases/(default)/documents/" +
        "spaces/vesselCalls/lineRegistry/{1}"
    ) -f $Project, $DocumentId

    return @{
        update = @{
            name = $DocumentName
            fields = ConvertTo-FirestoreLineFields `
                -Entry $Entry `
                -UpdatedByValue $UpdatedByValue
        }
        updateTransforms = @(
            @{
                fieldPath = "updatedAt"
                setToServerValue = "REQUEST_TIME"
            }
        )
    }
}

function New-FirestoreVesselWrite {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Entry,

        [Parameter(Mandatory = $true)]
        [string]$Project,

        [Parameter(Mandatory = $true)]
        [string]$UpdatedByValue
    )

    $DocumentId = Get-NormalizedString $Entry.documentId

    $DocumentName = (
        "projects/{0}/databases/(default)/documents/" +
        "spaces/vesselCalls/vesselRegistry/{1}"
    ) -f $Project, $DocumentId

    return @{
        update = @{
            name = $DocumentName
            fields = ConvertTo-FirestoreVesselFields `
                -Entry $Entry `
                -UpdatedByValue $UpdatedByValue
        }
        updateTransforms = @(
            @{
                fieldPath = "updatedAt"
                setToServerValue = "REQUEST_TIME"
            }
        )
    }
}

Write-Host ""
Write-Host "============================================"
Write-Host " Epistola Vessel Registry Import"
Write-Host "============================================"
Write-Host ""

$ResolvedLineInputPath = Resolve-RegistryFile -Path $LineInputPath
$ResolvedVesselInputPath = Resolve-RegistryFile -Path $VesselInputPath

Write-Host "Project : $ProjectId"
Write-Host "Lines   : $ResolvedLineInputPath"
Write-Host "Vessels : $ResolvedVesselInputPath"
Write-Host ""

$LineEntries = Read-RegistryJson -Path $ResolvedLineInputPath
$VesselEntries = Read-RegistryJson -Path $ResolvedVesselInputPath

if ($LineEntries.Count -eq 0) {
    throw "Line registry contains no records."
}

if ($VesselEntries.Count -eq 0) {
    throw "Vessel registry contains no records."
}

Write-Host "Validating line registry..."

for ($Index = 0; $Index -lt $LineEntries.Count; $Index++) {
    Assert-LineEntry `
        -Entry $LineEntries[$Index] `
        -Index ($Index + 1)
}

Write-Host "Validating vessel registry..."

for ($Index = 0; $Index -lt $VesselEntries.Count; $Index++) {
    Assert-VesselEntry `
        -Entry $VesselEntries[$Index] `
        -Index ($Index + 1)
}

$DuplicateLineIds = @(
    $LineEntries |
        Group-Object documentId |
        Where-Object { $_.Count -gt 1 }
)

if ($DuplicateLineIds.Count -gt 0) {
    $Values = (
        $DuplicateLineIds |
            ForEach-Object { $_.Name }
    ) -join ", "

    throw "Duplicate line documentId values: $Values"
}

$DuplicateVesselIds = @(
    $VesselEntries |
        Group-Object documentId |
        Where-Object { $_.Count -gt 1 }
)

if ($DuplicateVesselIds.Count -gt 0) {
    $Values = (
        $DuplicateVesselIds |
            ForEach-Object { $_.Name }
    ) -join ", "

    throw "Duplicate vessel documentId values: $Values"
}

$EntriesWithImo = @(
    $VesselEntries |
        Where-Object {
            $null -ne $_.imo -and
            -not [string]::IsNullOrWhiteSpace("$($_.imo)")
        }
)

$DuplicateImos = @(
    $EntriesWithImo |
        Group-Object imo |
        Where-Object { $_.Count -gt 1 }
)

if ($DuplicateImos.Count -gt 0) {
    $Values = (
        $DuplicateImos |
            ForEach-Object { $_.Name }
    ) -join ", "

    throw "Duplicate IMO values: $Values"
}

$KnownLineIds = @(
    $LineEntries |
        ForEach-Object {
            Get-NormalizedString $_.documentId
        }
)

$UnknownVesselLines = @(
    $VesselEntries |
        Where-Object {
            (Get-NormalizedString $_.lineId) -notin $KnownLineIds
        }
)

if ($UnknownVesselLines.Count -gt 0) {
    $Values = (
        $UnknownVesselLines |
            ForEach-Object {
                "$($_.name) -> $($_.lineId)"
            }
    ) -join ", "

    throw "Vessels reference missing lineRegistry documents: $Values"
}

$VerifiedLines = @(
    $LineEntries |
        Where-Object { $_.isVerified -eq $true }
)

$UnverifiedLines = @(
    $LineEntries |
        Where-Object { $_.isVerified -ne $true }
)

$VerifiedVessels = @(
    $VesselEntries |
        Where-Object { $_.isVerified -eq $true }
)

$UnverifiedVessels = @(
    $VesselEntries |
        Where-Object { $_.isVerified -ne $true }
)

$ContainerEntries = @(
    $VesselEntries |
        Where-Object { $_.defaultWorkType -eq "container" }
)

$BulkEntries = @(
    $VesselEntries |
        Where-Object { $_.defaultWorkType -eq "bulk" }
)

$OtherEntries = @(
    $VesselEntries |
        Where-Object { $_.defaultWorkType -eq "other" }
)

$UnknownEntries = @(
    $VesselEntries |
        Where-Object { $_.defaultWorkType -eq "unknown" }
)

$SwitchableEntries = @(
    $VesselEntries |
        Where-Object {
            @($_.allowedWorkTypes).Count -gt 1
        }
)

$TotalWrites = $LineEntries.Count + $VesselEntries.Count

Write-Host ""
Write-Host "Validation completed."
Write-Host ""
Write-Host "Lines total        : $($LineEntries.Count)"
Write-Host "Lines verified     : $($VerifiedLines.Count)"
Write-Host "Lines needs review : $($UnverifiedLines.Count)"
Write-Host ""
Write-Host "Vessels total      : $($VesselEntries.Count)"
Write-Host "Vessels verified   : $($VerifiedVessels.Count)"
Write-Host "Vessels review     : $($UnverifiedVessels.Count)"
Write-Host "Container default  : $($ContainerEntries.Count)"
Write-Host "Bulk default       : $($BulkEntries.Count)"
Write-Host "Other default      : $($OtherEntries.Count)"
Write-Host "Unknown default    : $($UnknownEntries.Count)"
Write-Host "Switchable         : $($SwitchableEntries.Count)"
Write-Host ""
Write-Host "Total writes       : $TotalWrites"
Write-Host ""

if ($UnverifiedLines.Count -gt 0) {
    Write-Host "Unverified lines:"
    Write-Host ""

    $UnverifiedLines |
        Select-Object `
            documentId,
            displayName,
            defaultWorkType |
        Format-Table -AutoSize

    Write-Host ""
}

if ($UnverifiedVessels.Count -gt 0) {
    Write-Host "Unverified vessels:"
    Write-Host ""

    $UnverifiedVessels |
        Select-Object `
            documentId,
            name,
            imo,
            lineId,
            physicalType,
            defaultWorkType |
        Format-Table -AutoSize

    Write-Host ""
}

Write-Host "Line registry preview:"
Write-Host ""

$LineEntries |
    Select-Object `
        documentId,
        displayName,
        defaultWorkType,
        isVerified |
    Format-Table -AutoSize

Write-Host ""
Write-Host "First 10 vessel records:"
Write-Host ""

$VesselEntries |
    Select-Object `
        -First 10 `
        documentId,
        name,
        imo,
        lineId,
        physicalType,
        defaultWorkType,
        @{
            Name = "allowedWorkTypes"
            Expression = {
                @($_.allowedWorkTypes) -join ","
            }
        } |
    Format-Table -AutoSize

if ($DryRun) {
    Write-Host ""
    Write-Host "DRY RUN completed."
    Write-Host "Firestore was NOT modified."
    Write-Host ""

    exit 0
}

if ([string]::IsNullOrWhiteSpace($AccessToken)) {
    throw @"
AccessToken is required for production import.

Nothing was written.

Run with -DryRun first.
Production authorization will be configured separately.
"@
}

$Writes = @()

foreach ($Entry in $LineEntries) {
    $Writes += New-FirestoreLineWrite `
        -Entry $Entry `
        -Project $ProjectId `
        -UpdatedByValue $UpdatedBy
}

foreach ($Entry in $VesselEntries) {
    $Writes += New-FirestoreVesselWrite `
        -Entry $Entry `
        -Project $ProjectId `
        -UpdatedByValue $UpdatedBy
}

if ($Writes.Count -gt 500) {
    throw "Firestore commit supports at most 500 writes. Current writes: $($Writes.Count)"
}

$CommitBody = @{
    writes = $Writes
} | ConvertTo-Json -Depth 20 -Compress

$CommitUrl = (
    "https://firestore.googleapis.com/v1/projects/{0}/" +
    "databases/(default)/documents:commit"
) -f $ProjectId

Write-Host ""
Write-Host "WARNING: writing to production Firestore."
Write-Host "Line documents   : $($LineEntries.Count)"
Write-Host "Vessel documents : $($VesselEntries.Count)"
Write-Host "Total writes     : $($Writes.Count)"
Write-Host ""

$Headers = @{
    Authorization = "Bearer $AccessToken"
    "Content-Type" = "application/json; charset=utf-8"
}

$Response = Invoke-RestMethod `
    -Method Post `
    -Uri $CommitUrl `
    -Headers $Headers `
    -Body ([System.Text.Encoding]::UTF8.GetBytes($CommitBody))

Write-Host ""
Write-Host "Import completed successfully."
Write-Host "Documents written: $($Writes.Count)"

if ($null -ne $Response.commitTime) {
    Write-Host "Commit time: $($Response.commitTime)"
}

Write-Host ""
