<#
.SYNOPSIS
    Project Structure Validation Script

.DESCRIPTION
    This script validates the new optimized dotfiles project structure,
    ensuring all components are correctly organized and functional.

.PARAMETER Fix
    Attempt to automatically fix detected structure issues

.PARAMETER Detailed
    Show detailed validation output

.PARAMETER OutputFormat
    Output format: Console, JSON, or Both

.EXAMPLE
    .\validate-structure.ps1
    Performs basic structure validation

.EXAMPLE
    .\validate-structure.ps1 -Fix -Detailed
    Performs detailed validation and attempts to fix issues

.EXAMPLE
    .\validate-structure.ps1 -OutputFormat JSON
    Outputs validation results in JSON format
#>

param(
    [switch]$Fix,
    [switch]$Detailed,

    [ValidateSet('Console', 'JSON', 'Both')]
    [string]$OutputFormat = 'Console'
)

# Script configuration
$script:SourceRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$script:ValidationResults = @{}
$script:Issues = @()
$script:Fixes = @()

# Initialize validation results
function Initialize-ValidationResults {
    $script:ValidationResults = @{
        Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        ProjectVersion = '2.0.0'
        OverallStatus = 'UNKNOWN'
        Categories = @{
            CoreStructure = @{ Status = 'UNKNOWN'; Score = 0; MaxScore = 0; Issues = @(); Fixes = @() }
            ConfigFiles = @{ Status = 'UNKNOWN'; Score = 0; MaxScore = 0; Issues = @(); Fixes = @() }
            Infrastructure = @{ Status = 'UNKNOWN'; Score = 0; MaxScore = 0; Issues = @(); Fixes = @() }
            Scripts = @{ Status = 'UNKNOWN'; Score = 0; MaxScore = 0; Issues = @(); Fixes = @() }
            Documentation = @{ Status = 'UNKNOWN'; Score = 0; MaxScore = 0; Issues = @(); Fixes = @() }
            Migration = @{ Status = 'UNKNOWN'; Score = 0; MaxScore = 0; Issues = @(); Fixes = @() }
        }
        Summary = @{
            TotalChecks = 0
            PassedChecks = 0
            FailedChecks = 0
            FixedIssues = 0
            StructureVersion = '2.0.0'
        }
    }
}

# Logging function
function Write-ValidationLog {
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Message,

        [Parameter(Position = 1)]
        [ValidateSet('INFO', 'SUCCESS', 'WARN', 'ERROR', 'DEBUG')]
        [string]$Level = "INFO"
    )

    if ($OutputFormat -eq 'Console' -or $OutputFormat -eq 'Both') {
        switch ($Level) {
            "INFO" { Write-Host "[INFO] $Message" -ForegroundColor White }
            "SUCCESS" { Write-Host "[✓] $Message" -ForegroundColor Green }
            "WARN" { Write-Host "[!] $Message" -ForegroundColor Yellow }
            "ERROR" { Write-Host "[✗] $Message" -ForegroundColor Red }
            "DEBUG" {
                if ($Detailed) {
                    Write-Host "[DEBUG] $Message" -ForegroundColor Gray
                }
            }
            default { Write-Host "[INFO] $Message" }
        }
    }
}

# Update category score
function Update-CategoryScore {
    param(
        [string]$Category,
        [int]$Score,
        [int]$MaxScore = 1
    )

    $script:ValidationResults.Categories[$Category].Score += $Score
    $script:ValidationResults.Categories[$Category].MaxScore += $MaxScore

    # Update summary
    $script:ValidationResults.Summary.TotalChecks += $MaxScore
    $script:ValidationResults.Summary.PassedChecks += $Score
    $script:ValidationResults.Summary.FailedChecks += ($MaxScore - $Score)
}

# Add issue to category
function Add-CategoryIssue {
    param(
        [string]$Category,
        [string]$Issue,
        [string]$Fix = $null
    )

    $script:ValidationResults.Categories[$Category].Issues += $Issue
    $script:Issues += @{ Category = $Category; Issue = $Issue; Fix = $Fix }

    if ($Fix) {
        $script:ValidationResults.Categories[$Category].Fixes += $Fix
    }
}

# Test core directory structure
function Test-CoreStructure {
    Write-ValidationLog "Validating core directory structure..." "INFO"

    $requiredDirectories = @{
        'configs' = 'Application configurations directory'
        'tools' = 'Utility scripts directory'
        'modules' = 'PowerShell modules directory'
        'docs' = 'Documentation directory'
        'bin' = 'Binary shortcuts directory'
        '.dotfiles' = 'Infrastructure directory'
        '.dotfiles\logs' = 'Centralized logging directory'
        '.dotfiles\backups' = 'Backup storage directory'
        '.dotfiles\cache' = 'Cache directory'
    }

    foreach ($dir in $requiredDirectories.Keys) {
        $fullPath = Join-Path $script:SourceRoot $dir
        $description = $requiredDirectories[$dir]

        if (Test-Path $fullPath -PathType Container) {
            Write-ValidationLog "$description exists: $dir" "SUCCESS"
            Update-CategoryScore -Category "CoreStructure" -Score 1
        } else {
            Write-ValidationLog "$description missing: $dir" "ERROR"
            Add-CategoryIssue -Category "CoreStructure" -Issue "Missing directory: $dir" -Fix "New-Item -ItemType Directory -Path '$fullPath' -Force"
            Update-CategoryScore -Category "CoreStructure" -Score 0

            if ($Fix) {
                try {
                    New-Item -ItemType Directory -Path $fullPath -Force | Out-Null
                    Write-ValidationLog "Created directory: $dir" "SUCCESS"
                    $script:ValidationResults.Summary.FixedIssues++
                } catch {
                    Write-ValidationLog "Failed to create directory $dir`: $($_.Exception.Message)" "ERROR"
                }
            }
        }
    }
}

# Test configuration files structure
function Test-ConfigFiles {
    Write-ValidationLog "Validating configuration files structure..." "INFO"

    $configComponents = @{
        'configs\git' = @('gitconfig', 'gitignore_global', 'gitmessage')
        'configs\powershell' = @('Microsoft.PowerShell_profile.ps1')
        'configs\starship' = @('starship.toml')
        'configs\neovim' = @('init.lua')
        'configs\WindowsTerminal' = @('settings.json')
        'configs\scoop' = @('config.json')
    }

    foreach ($component in $configComponents.Keys) {
        $componentPath = Join-Path $script:SourceRoot $component

        if (Test-Path $componentPath -PathType Container) {
            Write-ValidationLog "Configuration component exists: $component" "SUCCESS"
            Update-CategoryScore -Category "ConfigFiles" -Score 1

            # Check for expected files
            $expectedFiles = $configComponents[$component]
            foreach ($file in $expectedFiles) {
                $filePath = Join-Path $componentPath $file
                if (Test-Path $filePath) {
                    Write-ValidationLog "Configuration file found: $component\$file" "DEBUG"
                } else {
                    Write-ValidationLog "Configuration file missing: $component\$file" "WARN"
                    Add-CategoryIssue -Category "ConfigFiles" -Issue "Missing configuration file: $component\$file"
                }
            }
        } else {
            Write-ValidationLog "Configuration component missing: $component" "ERROR"
            Add-CategoryIssue -Category "ConfigFiles" -Issue "Missing configuration component: $component" -Fix "New-Item -ItemType Directory -Path '$componentPath' -Force"
            Update-CategoryScore -Category "ConfigFiles" -Score 0

            if ($Fix) {
                try {
                    New-Item -ItemType Directory -Path $componentPath -Force | Out-Null
                    Write-ValidationLog "Created configuration component: $component" "SUCCESS"
                    $script:ValidationResults.Summary.FixedIssues++
                } catch {
                    Write-ValidationLog "Failed to create component $component`: $($_.Exception.Message)" "ERROR"
                }
            }
        }
    }
}

# Test infrastructure components
function Test-Infrastructure {
    Write-ValidationLog "Validating infrastructure components..." "INFO"

    # Test configuration mapping file
    $configMappingPath = Join-Path $script:SourceRoot '.dotfiles\config-mapping.json'
    if (Test-Path $configMappingPath) {
        try {
            $configMapping = Get-Content $configMappingPath -Raw | ConvertFrom-Json
            if ($configMapping.version -and $configMapping.configurations) {
                Write-ValidationLog "Configuration mapping file is valid" "SUCCESS"
                Update-CategoryScore -Category "Infrastructure" -Score 1
            } else {
                Write-ValidationLog "Configuration mapping file is invalid" "ERROR"
                Add-CategoryIssue -Category "Infrastructure" -Issue "Invalid configuration mapping structure"
                Update-CategoryScore -Category "Infrastructure" -Score 0
            }
        } catch {
            Write-ValidationLog "Failed to parse configuration mapping: $($_.Exception.Message)" "ERROR"
            Add-CategoryIssue -Category "Infrastructure" -Issue "Configuration mapping parse error"
            Update-CategoryScore -Category "Infrastructure" -Score 0
        }
    } else {
        Write-ValidationLog "Configuration mapping file missing" "ERROR"
        Add-CategoryIssue -Category "Infrastructure" -Issue "Missing config-mapping.json"
        Update-CategoryScore -Category "Infrastructure" -Score 0
    }

    # Test .gitignore updates
    $gitignorePath = Join-Path $script:SourceRoot '.gitignore'
    if (Test-Path $gitignorePath) {
        $gitignoreContent = Get-Content $gitignorePath -Raw
        if ($gitignoreContent -match '\.dotfiles/logs/' -and $gitignoreContent -match '\.dotfiles/cache/') {
            Write-ValidationLog ".gitignore includes new structure paths" "SUCCESS"
            Update-CategoryScore -Category "Infrastructure" -Score 1
        } else {
            Write-ValidationLog ".gitignore missing new structure paths" "WARN"
            Add-CategoryIssue -Category "Infrastructure" -Issue ".gitignore needs updating for new structure"
            Update-CategoryScore -Category "Infrastructure" -Score 0
        }
    } else {
        Write-ValidationLog ".gitignore file missing" "ERROR"
        Add-CategoryIssue -Category "Infrastructure" -Issue "Missing .gitignore file"
        Update-CategoryScore -Category "Infrastructure" -Score 0
    }
}

# Test core scripts
function Test-Scripts {
    Write-ValidationLog "Validating core scripts..." "INFO"

    $coreScripts = @{
        'manage.ps1' = 'Unified management interface'
        'detect-environment.ps1' = 'Environment detection script'
        'install_apps.ps1' = 'Application installation script'
        'install.ps1' = 'Configuration deployment script'
        'health-check.ps1' = 'Health check script'
    }

    foreach ($script in $coreScripts.Keys) {
        $scriptPath = Join-Path $script:SourceRoot $script
        $description = $coreScripts[$script]

        if (Test-Path $scriptPath) {
            Write-ValidationLog "$description exists: $script" "SUCCESS"
            Update-CategoryScore -Category "Scripts" -Score 1

            # Basic syntax check
            try {
                $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $scriptPath -Raw), [ref]$null)
                Write-ValidationLog "$script syntax is valid" "DEBUG"
            } catch {
                Write-ValidationLog "$script has syntax errors: $($_.Exception.Message)" "WARN"
                Add-CategoryIssue -Category "Scripts" -Issue "Syntax error in $script"
            }
        } else {
            Write-ValidationLog "$description missing: $script" "ERROR"
            Add-CategoryIssue -Category "Scripts" -Issue "Missing core script: $script"
            Update-CategoryScore -Category "Scripts" -Score 0
        }
    }

    # Test tools directory
    $toolsDir = Join-Path $script:SourceRoot 'tools'
    if (Test-Path $toolsDir) {
        $toolScripts = Get-ChildItem $toolsDir -Filter '*.ps1' -ErrorAction SilentlyContinue
        Write-ValidationLog "Found $($toolScripts.Count) tool scripts in tools directory" "INFO"
        Update-CategoryScore -Category "Scripts" -Score 1
    } else {
        Write-ValidationLog "Tools directory missing" "ERROR"
        Add-CategoryIssue -Category "Scripts" -Issue "Missing tools directory"
        Update-CategoryScore -Category "Scripts" -Score 0
    }
}

# Test documentation
function Test-Documentation {
    Write-ValidationLog "Validating documentation..." "INFO"

    $requiredDocs = @{
        'README.md' = 'Main project documentation'
        'ARCHITECTURE.md' = 'Architecture documentation'
        'OPTIMIZATION_REPORT.md' = 'Optimization report'
        'USAGE_GUIDE.md' = 'Usage guide'
    }

    foreach ($doc in $requiredDocs.Keys) {
        $docPath = Join-Path $script:SourceRoot $doc
        $description = $requiredDocs[$doc]

        if (Test-Path $docPath) {
            $content = Get-Content $docPath -Raw
            if ($content.Length -gt 100) {
                Write-ValidationLog "$description exists and has content: $doc" "SUCCESS"
                Update-CategoryScore -Category "Documentation" -Score 1
            } else {
                Write-ValidationLog "$description exists but appears empty: $doc" "WARN"
                Add-CategoryIssue -Category "Documentation" -Issue "Document appears empty: $doc"
                Update-CategoryScore -Category "Documentation" -Score 0
            }
        } else {
            Write-ValidationLog "$description missing: $doc" "ERROR"
            Add-CategoryIssue -Category "Documentation" -Issue "Missing documentation: $doc"
            Update-CategoryScore -Category "Documentation" -Score 0
        }
    }

    # Check docs directory
    $docsDir = Join-Path $script:SourceRoot 'docs'
    if (Test-Path $docsDir) {
        $docFiles = Get-ChildItem $docsDir -Filter '*.md' -ErrorAction SilentlyContinue
        Write-ValidationLog "Found $($docFiles.Count) documentation files in docs directory" "INFO"
        Update-CategoryScore -Category "Documentation" -Score 1
    } else {
        Write-ValidationLog "Docs directory missing" "WARN"
        Add-CategoryIssue -Category "Documentation" -Issue "Missing docs directory"
        Update-CategoryScore -Category "Documentation" -Score 0
    }
}

# Test migration completion
function Test-Migration {
    Write-ValidationLog "Validating migration from v1.x structure..." "INFO"

    # Check for old structure remnants that should be cleaned up
    $oldStructureItems = @(
        'git',
        'powershell',
        'starship',
        'neovim',
        'WindowsTerminal',
        'scoop',
        'scripts',
        'auto-sync.ps1',
        'dev-link.ps1'
    )

    $cleanupNeeded = @()
    foreach ($item in $oldStructureItems) {
        $itemPath = Join-Path $script:SourceRoot $item
        if (Test-Path $itemPath) {
            $cleanupNeeded += $item
            Write-ValidationLog "Old structure remnant found: $item" "WARN"
            Add-CategoryIssue -Category "Migration" -Issue "Old structure item exists: $item" -Fix "Remove-Item '$itemPath' -Force -Recurse"
        }
    }

    if ($cleanupNeeded.Count -eq 0) {
        Write-ValidationLog "Migration cleanup complete - no old structure remnants" "SUCCESS"
        Update-CategoryScore -Category "Migration" -Score 1
    } else {
        Write-ValidationLog "$($cleanupNeeded.Count) old structure items need cleanup" "WARN"
        Update-CategoryScore -Category "Migration" -Score 0

        if ($Fix) {
            foreach ($item in $cleanupNeeded) {
                $itemPath = Join-Path $script:SourceRoot $item
                try {
                    Remove-Item $itemPath -Force -Recurse -ErrorAction Stop
                    Write-ValidationLog "Cleaned up old structure item: $item" "SUCCESS"
                    $script:ValidationResults.Summary.FixedIssues++
                } catch {
                    Write-ValidationLog "Failed to cleanup $item`: $($_.Exception.Message)" "ERROR"
                }
            }
        }
    }

    # Check that new structure is being used
    $newStructureScore = 0
    $maxNewStructureScore = 3

    # Test unified management script
    $managePath = Join-Path $script:SourceRoot 'manage.ps1'
    if (Test-Path $managePath) {
        Write-ValidationLog "Unified management script available" "SUCCESS"
        $newStructureScore++
    }

    # Test configs directory usage
    $configsDir = Join-Path $script:SourceRoot 'configs'
    if (Test-Path $configsDir) {
        $configDirs = Get-ChildItem $configsDir -Directory -ErrorAction SilentlyContinue
        if ($configDirs.Count -ge 3) {
            Write-ValidationLog "Configuration files properly organized in configs directory" "SUCCESS"
            $newStructureScore++
        }
    }

    # Test infrastructure directory
    $dotfilesDir = Join-Path $script:SourceRoot '.dotfiles'
    if (Test-Path $dotfilesDir) {
        $infraItems = Get-ChildItem $dotfilesDir -ErrorAction SilentlyContinue
        if ($infraItems.Count -ge 2) {
            Write-ValidationLog "Infrastructure directory properly set up" "SUCCESS"
            $newStructureScore++
        }
    }

    Update-CategoryScore -Category "Migration" -Score $newStructureScore -MaxScore $maxNewStructureScore
}

# Calculate final status
function Calculate-FinalStatus {
    $totalScore = 0
    $totalMaxScore = 0

    foreach ($category in $script:ValidationResults.Categories.Values) {
        $totalScore += $category.Score
        $totalMaxScore += $category.MaxScore

        # Calculate category status
        if ($category.MaxScore -eq 0) {
            $category.Status = 'NOT_TESTED'
        } elseif ($category.Score -eq $category.MaxScore) {
            $category.Status = 'PASSED'
        } elseif ($category.Score -gt 0) {
            $category.Status = 'PARTIAL'
        } else {
            $category.Status = 'FAILED'
        }
    }

    # Calculate overall status
    if ($totalMaxScore -eq 0) {
        $script:ValidationResults.OverallStatus = 'UNKNOWN'
    } elseif ($totalScore -eq $totalMaxScore) {
        $script:ValidationResults.OverallStatus = 'PASSED'
    } elseif ($totalScore -ge ($totalMaxScore * 0.8)) {
        $script:ValidationResults.OverallStatus = 'GOOD'
    } elseif ($totalScore -ge ($totalMaxScore * 0.6)) {
        $script:ValidationResults.OverallStatus = 'PARTIAL'
    } else {
        $script:ValidationResults.OverallStatus = 'FAILED'
    }

    $script:ValidationResults.Summary.TotalChecks = $totalMaxScore
    $script:ValidationResults.Summary.PassedChecks = $totalScore
    $script:ValidationResults.Summary.FailedChecks = $totalMaxScore - $totalScore
}

# Output results
function Output-Results {
    if ($OutputFormat -eq 'Console' -or $OutputFormat -eq 'Both') {
        Write-ValidationLog ("=" * 60) "INFO"
        Write-ValidationLog "DOTFILES STRUCTURE VALIDATION REPORT" "INFO"
        Write-ValidationLog ("=" * 60) "INFO"
        Write-ValidationLog " " "INFO"

        Write-ValidationLog "Overall Status: $($script:ValidationResults.OverallStatus)" $(
            if ($script:ValidationResults.OverallStatus -eq 'PASSED') { 'SUCCESS' }
            elseif ($script:ValidationResults.OverallStatus -eq 'GOOD') { 'SUCCESS' }
            elseif ($script:ValidationResults.OverallStatus -eq 'PARTIAL') { 'WARN' }
            else { 'ERROR' }
        )

        Write-ValidationLog "Project Version: $($script:ValidationResults.ProjectVersion)"
        Write-ValidationLog "Validation Time: $($script:ValidationResults.Timestamp)"
        Write-ValidationLog " " "INFO"

        Write-ValidationLog "SUMMARY:" "INFO"
        Write-ValidationLog "  Total Checks: $($script:ValidationResults.Summary.TotalChecks)"
        Write-ValidationLog "  Passed: $($script:ValidationResults.Summary.PassedChecks)" "SUCCESS"
        Write-ValidationLog "  Failed: $($script:ValidationResults.Summary.FailedChecks)" $(
            if ($script:ValidationResults.Summary.FailedChecks -eq 0) { 'SUCCESS' } else { 'ERROR' }
        )
        Write-ValidationLog "  Fixed Issues: $($script:ValidationResults.Summary.FixedIssues)" $(
            if ($script:ValidationResults.Summary.FixedIssues -gt 0) { 'SUCCESS' } else { 'INFO' }
        )
        Write-ValidationLog " " "INFO"

        Write-ValidationLog "CATEGORY RESULTS:" "INFO"
        foreach ($categoryName in $script:ValidationResults.Categories.Keys) {
            $category = $script:ValidationResults.Categories[$categoryName]
            $score = "$($category.Score)/$($category.MaxScore)"
            $status = $category.Status

            $statusColor = switch ($status) {
                'PASSED' { 'SUCCESS' }
                'PARTIAL' { 'WARN' }
                'FAILED' { 'ERROR' }
                default { 'INFO' }
            }

            Write-ValidationLog "  $categoryName`: $score [$status]" $statusColor

            if ($Detailed -and $category.Issues.Count -gt 0) {
                foreach ($issue in $category.Issues) {
                    Write-ValidationLog "    - $issue" "ERROR"
                }
            }
        }

        if ($script:Issues.Count -gt 0 -and -not $Detailed) {
            Write-ValidationLog ""
            Write-ValidationLog "Run with -Detailed to see specific issues" "INFO"
        }

        if ($script:Issues.Count -gt 0 -and -not $Fix) {
            Write-ValidationLog "Run with -Fix to attempt automatic repairs" "INFO"
        }
    }

    if ($OutputFormat -eq 'JSON' -or $OutputFormat -eq 'Both') {
        $jsonOutput = $script:ValidationResults | ConvertTo-Json -Depth 10
        if ($OutputFormat -eq 'JSON') {
            Write-Output $jsonOutput
        } else {
            Write-ValidationLog ""
            Write-ValidationLog "JSON OUTPUT:" "INFO"
            Write-Output $jsonOutput
        }
    }
}

# Main execution
function Main {
    Write-ValidationLog "Starting dotfiles structure validation..." "INFO"
    Write-ValidationLog "Source: $script:SourceRoot" "DEBUG"
    Write-ValidationLog ""

    Initialize-ValidationResults

    # Run validation tests
    Test-CoreStructure
    Test-ConfigFiles
    Test-Infrastructure
    Test-Scripts
    Test-Documentation
    Test-Migration

    # Calculate final results
    Calculate-FinalStatus

    # Output results
    Output-Results

    # Set exit code based on results
    $exitCode = switch ($script:ValidationResults.OverallStatus) {
        'PASSED' { 0 }
        'GOOD' { 0 }
        'PARTIAL' { 1 }
        default { 2 }
    }

    Write-ValidationLog " " "INFO"
    Write-ValidationLog "Validation completed with exit code: $exitCode" $(
        if ($exitCode -eq 0) { 'SUCCESS' } else { 'WARN' }
    )

    exit $exitCode
}

# Execute main function
Main
