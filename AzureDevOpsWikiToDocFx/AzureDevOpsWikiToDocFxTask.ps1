[CmdletBinding()]
param()

# For more information on the Azure DevOps Task SDK:
# https://github.com/Microsoft/vsts-task-lib
Trace-VstsEnteringInvocation $MyInvocation
try {
    # Reading inputs
    $SourceFolder = Get-VstsInput -Name SourceFolder -Require
    $TargetFolder = Get-VstsInput -Name TargetFolder -Require

    # Validating input
    Write-VstsTaskVerbose "Source folder: $SourceFolder"
    Write-VstsTaskVerbose "Target folder: $TargetFolder"

    Assert-VstsPath -LiteralPath $SourceFolder -PathType Container
    
    if (Test-Path -Path $TargetFolder) {
        throw "Target folder already exists"
    }

    # Template dir
    $SearchTemplateDir = Join-Path $SourceFolder ".docfx_template"
    if (Test-Path -Path $SearchTemplateDir -PathType "Container") {
        $TemplateDir = $SearchTemplateDir
    }
    else {
        $TemplateDir = Join-Path $PSScriptRoot "docfx_template"
    }
    
    Write-VstsTaskVerbose "Template directory: $TemplateDir"

    # Run the script
    $Script = "AzureDevOpsWikiToDocFxInclude.ps1"
    Write-VstsTaskVerbose "Dot-sourcing $Script"
    $ScriptPath = Join-Path $PSScriptRoot $Script
    . $ScriptPath

    Write-VstsTaskVerbose "Starting"
    Copy-DevOpsWikiToDocFx -InputDir $InputDir -OutputDir $OutputDir -TemplateDir $TemplateDir -TargetAudience $TargetAudience
} finally {
    Trace-VstsLeavingInvocation $MyInvocation
}
