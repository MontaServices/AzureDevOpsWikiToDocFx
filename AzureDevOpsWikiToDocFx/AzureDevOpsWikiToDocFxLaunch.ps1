param (
    $InputDir,
    $OutputDir
)

$ErrorActionPreference = "Stop"

$IncludePath = Join-Path $PSScriptRoot "AzureDevOpsWikiToDocFxInclude.ps1"
. $IncludePath

Copy-DevOpsWikiToDocFx -InputDir $InputDir -OutputDir $OutputDir