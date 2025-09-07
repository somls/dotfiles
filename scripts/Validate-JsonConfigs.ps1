# Validate-JsonConfigs.ps1
# JSON configuration file validation script

[CmdletBinding()]
param(
    [string[]]$Path = @(),
    [switch]$Recursive,
    [switch]$Fix,
    [switch]$Detailed,
    [switch]$UseSchema,
    [string]$SchemaPath = "",
    [switch]$ExportReport,
    [string]$ReportPath = "json-validation-report.json",
    [switch]$Quiet,
    [ValidateSet("Error", "Warning", "Info", "All")]
    [string]$Level = "All",
    [switch]$IncludeExamples
)

# Strict mode
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

# Global variables
$script:ProjectRoot = Split-Path $PSScriptRoot -Parent
$script:ValidationResults = @()
$script:StartTime = Get-Date

# JSON validation result class
function New-ValidationResult {
    param(
        [string]$FilePath,
        [bool]$IsValid = $false,
        [string]$Status = "Unknown",
        [string]$Message = "",
        [array]$Errors = @(),
        [array]$Warnings = @(),
        [hashtable]$Metadata = @{},
        [string]$Suggestion = ""
    )

    return @{
        FilePath = $FilePath
        IsValid = $IsValid
        Status = $Status
        Message = $Message
        Errors = $Errors
        Warnings = $Warnings
        Metadata = $Metadata
        Suggestion = $Suggestion
        ValidationDuration = [timespan]::Zero
        Timestamp = Get-Date
    }
}

# Output function
function Write-ValidationMessage {
    param(
        [string]$Message,
        [ValidateSet("Info", "Success", "Warning", "Error")]
        [string]$Type = "Info",
        [switch]$NoNewline
    )

    if ($Quiet -and $Type -eq "Info") { return }

    $color = switch ($Type) {
        "Success" { "Green" }
        "Error" { "Red" }
        "Warning" { "Yellow" }
        "Info" { "Cyan" }
    }

    $prefix = switch ($Type) {
        "Success" { "OK" }
        "Error" { "ERROR" }
        "Warning" { "WARN" }
        "Info" { "INFO" }
    }

    if ($NoNewline) {
        Write-Host " $prefix" -ForegroundColor $color -NoNewline
    } else {
        Write-Host "$prefix $Message" -ForegroundColor $color
    }
}

# Validate JSON syntax
function Test-JsonSyntax {
    param([string]$FilePath)

    $result = New-ValidationResult -FilePath $FilePath
    $timer = [System.Diagnostics.Stopwatch]::StartNew()

    try {
        # Read file content
        if (-not (Test-Path $FilePath)) {
            $result.Status = "Error"
            $result.Message = "File does not exist"
            $result.Errors += "Specified file path does not exist"
            return $result
        }

        $content = Get-Content $FilePath -Raw -Encoding UTF8 -ErrorAction Stop

        # Check empty file
        if ([string]::IsNullOrWhiteSpace($content)) {
            $result.Status = "Warning"
            $result.Message = "File is empty"
            $result.Warnings += "JSON file content is empty"
            $result.Suggestion = "Add valid JSON content"
            return $result
        }

        # Try to parse JSON
        $null = $content | ConvertFrom-Json -ErrorAction Stop

        $result.IsValid = $true
        $result.Status = "Success"
        $result.Message = "JSON syntax is valid"

        # Check best practices
        $warnings = @()

        # Check comments (JSON standard does not support)
        if ($content -match '//.*|/\*[\s\S]*?\*/') {
            $warnings += "Comments detected, JSON standard does not support comments"
        }

        # Check trailing commas
        if ($content -match ',\s*[\}\]]') {
            $warnings += "Trailing commas detected, may cause parser failures"
        }

        # Check single quotes
        if ($content -match "'[^']*':\s*|:\s*'[^']*'") {
            $warnings += "Single quotes detected, JSON standard requires double quotes"
        }

        if ($warnings -and $warnings.Count -gt 0) {
            $result.Status = "Warning"
            $result.Warnings = $warnings
            $result.Suggestion = "Follow JSON best practices for compatibility"
        }

    } catch {
        $result.IsValid = $false
        $result.Status = "Error"
        $result.Message = "JSON syntax error"
        $result.Errors += $_.Exception.Message

        # Try to provide more detailed error information
        $errorMessage = $_.Exception.Message
        if ($errorMessage -match "line (\d+)") {
            $lineNumber = $matches[1]
            $result.Suggestion = "Check JSON syntax error on line $lineNumber"
        } elseif ($errorMessage -match "position (\d+)") {
            $position = $matches[1]
            $result.Suggestion = "Check JSON syntax error at position $position"
        } else {
            $result.Suggestion = "Check JSON syntax, ensure all brackets match and syntax is correct"
        }
    } finally {
        $timer.Stop()
        $result.ValidationDuration = $timer.Elapsed
    }

    return $result
}

# Schema validation (if schema file provided)
function Test-JsonSchema {
    param(
        [string]$JsonFilePath,
        [string]$SchemaFilePath,
        [object]$Result
    )

    if (-not $UseSchema -or [string]::IsNullOrWhiteSpace($SchemaFilePath)) {
        return $Result
    }

    if (-not (Test-Path $SchemaFilePath)) {
        $Result.Warnings += "Schema file does not exist: $SchemaFilePath"
        return $Result
    }

    try {
        # More complex JSON schema validation logic can be added here
        # Currently only basic checks
        $schemaContent = Get-Content $SchemaFilePath -Raw -Encoding UTF8
        $null = $schemaContent | ConvertFrom-Json

        # Simple schema validation example
        $jsonContent = Get-Content $JsonFilePath -Raw -Encoding UTF8
        $jsonObject = $jsonContent | ConvertFrom-Json

        $schemaErrors = @()
        $schemaWarnings = @()

        # Schema validation rules can be added here based on specific needs
        # For example, check required fields, data types, etc.

        if ($schemaErrors -and $schemaErrors.Count -gt 0) {
            $Result.Status = "Error"
            $Result.IsValid = $false
            $Result.Errors += $schemaErrors
            $Result.Suggestion = "Fix schema validation errors to comply with defined JSON schema"
        } elseif ($schemaWarnings -and $schemaWarnings.Count -gt 0) {
            if ($Result.Status -eq "Success") {
                $Result.Status = "Warning"
            }
            $Result.Warnings += $schemaWarnings
        }

    } catch {
        $Result.Errors += "Schema validation failed: $($_.Exception.Message)"
        if ($Result.Status -eq "Success") {
            $Result.Status = "Warning"
        }
    }

    return $Result
}

# Auto-repair function
function Repair-JsonFile {
    param(
        [string]$FilePath,
        [object]$Result
    )

    if (-not $Fix) { return $Result }

    try {
        $content = Get-Content $FilePath -Raw -Encoding UTF8

        # Simple repair: format JSON
        if ($Result.IsValid) {
            $jsonObject = $content | ConvertFrom-Json
            $formattedContent = $jsonObject | ConvertTo-Json -Depth 10 -Compress:$false

            if ($content -ne $formattedContent) {
                # Create backup
                $backupPath = "$FilePath.backup"
                Copy-Item $FilePath $backupPath

                # Save repaired content
                $formattedContent | Out-File $FilePath -Encoding UTF8

                $Result.Message += " (auto-formatted)"
                $Result.Status = "Success"
                $Result.Metadata.AutoFixed = $true
                $Result.Metadata.BackupPath = $backupPath
            }
        }

    } catch {
        $Result.Warnings += "Auto-repair failed: $($_.Exception.Message)"
    }

    return $Result
}

# Display single validation result
function Show-ValidationResult {
    param([object]$Result)

    # Filter log level
    $shouldShow = switch ($Level) {
        "Error" { $Result.Status -eq "Error" }
        "Warning" { $Result.Status -in @("Error", "Warning") }
        "Info" { $Result.Status -in @("Error", "Warning", "Success") }
        "All" { $true }
    }

    if (-not $shouldShow) { return }

    # Output result
    $statusSymbol = switch ($Result.Status) {
        "Success" { " OK" }
        "Warning" { " WARN" }
        "Error" { " ERROR" }
        default { " ?" }
    }

    Write-Host $statusSymbol -ForegroundColor $(switch ($Result.Status) {
        "Success" { "Green" }
        "Warning" { "Yellow" }
        "Error" { "Red" }
        default { "White" }
    }) -NoNewline

    Write-Host " $($Result.FilePath): $($Result.Message)" -ForegroundColor White

    # Show detailed information
    if ($Detailed) {
        if ($Result.Errors -and $Result.Errors.Count -gt 0) {
            Write-Host "   Errors:" -ForegroundColor Red
            foreach ($error in $Result.Errors) {
                Write-Host "     - $error" -ForegroundColor Red
            }
        }

        if ($Result.Warnings -and $Result.Warnings.Count -gt 0) {
            Write-Host "   Warnings:" -ForegroundColor Yellow
            foreach ($warning in $Result.Warnings) {
                Write-Host "     - $warning" -ForegroundColor Yellow
            }
        }

        if (-not [string]::IsNullOrWhiteSpace($Result.Suggestion)) {
            Write-Host "   Suggestion: $($Result.Suggestion)" -ForegroundColor Cyan
        }

        if ($Result.ValidationDuration.TotalMilliseconds -gt 10) {
            Write-Host "   Duration: $($Result.ValidationDuration.TotalMilliseconds.ToString('F0'))ms" -ForegroundColor Gray
        }
    }
}

# Get JSON files to validate
function Get-JsonFiles {
    param([string[]]$InputPaths)

    $jsonFiles = @()

    if ($InputPaths.Count -eq 0) {
        # If no path specified, use project root and auto-enable recursive
        $InputPaths = @($script:ProjectRoot)
        $Recursive = $true
    }

    foreach ($inputPath in $InputPaths) {
        if ([System.IO.Path]::IsPathRooted($inputPath)) {
            $resolvedPath = $inputPath
        } else {
            $resolvedPath = Join-Path $script:ProjectRoot $inputPath
        }

        if (Test-Path $resolvedPath) {
            if ((Get-Item $resolvedPath).PSIsContainer) {
                # Directory
                if ($Recursive) {
                    $jsonFiles += Get-ChildItem $resolvedPath -Filter "*.json" -Recurse -File
                } else {
                    $jsonFiles += Get-ChildItem $resolvedPath -Filter "*.json" -File
                }
            } else {
                # File
                if ($resolvedPath.EndsWith('.json')) {
                    $jsonFiles += Get-Item $resolvedPath
                }
            }
        } else {
            Write-ValidationMessage "Path does not exist: $resolvedPath" "Warning"
        }
    }

    # Exclude example files (unless explicitly included)
    if (-not $IncludeExamples) {
        $jsonFiles = $jsonFiles | Where-Object { $_.Name -notmatch '\.example\.json$|\.sample\.json$|\.template\.json$' }
    }

    return $jsonFiles
}

# Export validation report
function Export-ValidationReport {
    if (-not $ExportReport) { return }

    try {
        $report = @{
            timestamp = $script:StartTime.ToString("yyyy-MM-ddTHH:mm:ss")
            version = "1.0.0"
            summary = @{
                totalFiles = $script:ValidationResults.Count
                validFiles = @($script:ValidationResults | Where-Object { $_.IsValid }).Count
                invalidFiles = @($script:ValidationResults | Where-Object { -not $_.IsValid }).Count
                warningFiles = @($script:ValidationResults | Where-Object { $_.Status -eq "Warning" }).Count
                averageValidationTime = if ($script:ValidationResults.Count -gt 0) {
                    [math]::Round(($script:ValidationResults | ForEach-Object { $_.ValidationDuration.TotalMilliseconds } | Measure-Object -Average).Average, 2)
                } else { 0 }
            }
            results = $script:ValidationResults | ForEach-Object {
                @{
                    filePath = $_.FilePath
                    isValid = $_.IsValid
                    status = $_.Status
                    message = $_.Message
                    errors = $_.Errors
                    warnings = $_.Warnings
                    metadata = $_.Metadata
                    suggestion = $_.Suggestion
                    validationDuration = $_.ValidationDuration.TotalMilliseconds
                }
            }
            configuration = @{
                recursive = $Recursive.IsPresent
                fix = $Fix.IsPresent
                useSchema = $UseSchema.IsPresent
                schemaPath = $SchemaPath
                level = $Level
                includeExamples = $IncludeExamples.IsPresent
            }
        }

        $reportPath = if ([System.IO.Path]::IsPathRooted($ReportPath)) {
            $ReportPath
        } else {
            Join-Path $script:ProjectRoot $ReportPath
        }

        $report | ConvertTo-Json -Depth 5 | Out-File $reportPath -Encoding UTF8
        Write-ValidationMessage "Validation report exported: $reportPath" "Success"

    } catch {
        Write-ValidationMessage "Failed to export report: $($_.Exception.Message)" "Error"
    }
}

# Main execution logic
function Start-JsonValidation {
    Write-ValidationMessage "Starting JSON configuration file validation" "Info"

    # Get files to validate
    $jsonFiles = Get-JsonFiles -InputPaths $Path

    if (-not $jsonFiles -or $jsonFiles.Count -eq 0) {
        Write-ValidationMessage "No JSON files found for validation" "Warning"
        return
    }

    $fileCount = if ($jsonFiles -is [array]) { $jsonFiles.Count } else { 1 }
    Write-ValidationMessage "Found $fileCount JSON files" "Info"

    # Validate each file
    foreach ($file in $jsonFiles) {
        $result = Test-JsonSyntax -FilePath $file.FullName

        # Schema validation
        if ($UseSchema) {
            $result = Test-JsonSchema -JsonFilePath $file.FullName -SchemaFilePath $SchemaPath -Result $result
        }

        # Auto-repair
        if ($Fix) {
            $result = Repair-JsonFile -FilePath $file.FullName -Result $result
        }

        $script:ValidationResults += $result

        # Show result
        Show-ValidationResult -Result $result
    }

    # Show summary
    Write-Host ""
    Write-ValidationMessage "Validation complete summary:" "Info"
    Write-ValidationMessage "Total files: $($script:ValidationResults.Count)" "Info"
    Write-ValidationMessage "Valid files: $(@($script:ValidationResults | Where-Object { $_.IsValid }).Count)" "Success"

    $invalidFiles = @($script:ValidationResults | Where-Object { -not $_.IsValid })
    $invalidCount = $invalidFiles.Count
    if ($invalidCount -gt 0) {
        Write-ValidationMessage "Invalid files: $invalidCount" "Error"
    }

    $warningFiles = @($script:ValidationResults | Where-Object { $_.Status -eq "Warning" })
    $warningCount = $warningFiles.Count
    if ($warningCount -gt 0) {
        Write-ValidationMessage "Warning files: $warningCount" "Warning"
    }

    $duration = (Get-Date) - $script:StartTime
    Write-ValidationMessage "Total time: $($duration.TotalSeconds.ToString('F2')) seconds" "Info"

    # Export report
    Export-ValidationReport

    # Return exit code
    if ($invalidCount -gt 0) {
        return 1
    } elseif ($warningCount -gt 0) {
        return 2
    } else {
        return 0
    }
}

# Execute validation
try {
    $exitCode = Start-JsonValidation
    exit $exitCode
} catch {
    Write-ValidationMessage "Fatal error during validation: $($_.Exception.Message)" "Error"
    exit 1
}