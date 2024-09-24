[CmdletBinding()]
param()

# For more information on the Azure DevOps Task SDK:
# https://github.com/Microsoft/vsts-task-lib
Trace-VstsEnteringInvocation $MyInvocation
try {
    # Reading inputs
    $SourceFolder = Get-VstsInput -Name SourceFolder -Require
    $TargetFolder = Get-VstsInput -Name TargetFolder -Require
    $TemplateDirName = Get-VstsInput -Name TemplateDir

    # Validating input
    Write-VstsTaskVerbose "Source folder: $SourceFolder"
    Write-VstsTaskVerbose "Target folder: $TargetFolder"

    # Paths
    Assert-VstsPath -LiteralPath $SourceFolder -PathType Container
    
    if (Test-Path -Path $TargetFolder) {
        throw "Target folder already exists"
    }

    # Template dir
    $TemplateDir = Join-Path $PSScriptRoot "docfx_template" # default

    # if a template dir is specified in config, check if it exists and use it
    if ($null -ne $TemplateDirName) {
        if ($TemplateDirName.Length -gt 0) {
            $SearchTemplateDir = Join-Path $SourceFolder $TemplateDirName
            $TemplateDirFound = Test-Path -Path $SearchTemplateDir -PathType "Container"
            if ($TemplateDirFound -ne $true)
            {
                throw "Template dir does not exist"
            }
            $TemplateDir = $SearchTemplateDir
        }
    }
    
    Write-VstsTaskVerbose "Template directory: $TemplateDir"

    # Run the script
    $Script = "AzureDevOpsWikiToDocFxInclude.ps1"
    Write-VstsTaskVerbose "Dot-sourcing $Script"
    $ScriptPath = Join-Path $PSScriptRoot $Script
    . $ScriptPath

    Write-VstsTaskVerbose "Starting"
    Copy-DevOpsWikiToDocFx -InputDir $SourceFolder -OutputDir $TargetFolder -TemplateDir $TemplateDir -TargetAudience $TargetAudience -AudienceKeywords $AudienceKeywordsParsed
} finally {
    Trace-VstsLeavingInvocation $MyInvocation
}
