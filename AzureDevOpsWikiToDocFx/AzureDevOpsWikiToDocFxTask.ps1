[CmdletBinding()]
param()

# For more information on the Azure DevOps Task SDK:
# https://github.com/Microsoft/vsts-task-lib
Trace-VstsEnteringInvocation $MyInvocation
try {
    # Reading inputs
    $SourceFolder = Get-VstsInput -Name SourceFolder -Require
    $TargetFolder = Get-VstsInput -Name TargetFolder -Require
    $DocfxGlobalMetadata = Get-VstsInput -Name DocfxGlobalMetadata

    # Validating input
    Write-VstsTaskVerbose "Source folder: $SourceFolder"
    Write-VstsTaskVerbose "Target folder: $TargetFolder"

    # Paths
    Assert-VstsPath -LiteralPath $SourceFolder -PathType Container
    
    if (Test-Path -Path $TargetFolder) {
        throw "Target folder already exists"
    }

    # Run the script
    $Script = "AzureDevOpsWikiToDocFxInclude.ps1"
    Write-VstsTaskVerbose "Dot-sourcing $Script"
    $ScriptPath = Join-Path $PSScriptRoot $Script
    . $ScriptPath

    Write-VstsTaskVerbose "Starting"
    Copy-DevOpsWikiToDocFx -InputDir $SourceFolder -OutputDir $TargetFolder -DocfxGlobalMetadata $DocfxGlobalMetadata
} finally {
    Trace-VstsLeavingInvocation $MyInvocation
}
