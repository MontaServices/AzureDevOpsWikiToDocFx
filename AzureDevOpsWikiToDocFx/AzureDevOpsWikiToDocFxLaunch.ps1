param (
    [Parameter(Mandatory=$true)]
    [string]$InputDir,

    [Parameter(Mandatory=$true)]
    [string]
    $OutputDir
)

$ErrorActionPreference = "Stop"

$IncludePath = Join-Path $PSScriptRoot "AzureDevOpsWikiToDocFxInclude.ps1"
. $IncludePath

Copy-DevOpsWikiToDocFx -InputDir $InputDir -OutputDir $OutputDir