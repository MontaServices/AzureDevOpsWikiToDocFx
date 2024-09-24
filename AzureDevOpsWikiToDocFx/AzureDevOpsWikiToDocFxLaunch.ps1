param (
    $InputDir,
    $OutputDir,
    $TemplateDir
)

$ErrorActionPreference = "Stop"

$IncludePath = Join-Path $PSScriptRoot "AzureDevOpsWikiToDocFxInclude.ps1"
. $IncludePath

Copy-DevOpsWikiToDocFx -InputDir $InputDir -OutputDir $OutputDir -TemplateDir $TemplateDir