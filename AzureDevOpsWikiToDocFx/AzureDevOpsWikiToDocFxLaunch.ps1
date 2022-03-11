param (
    $InputDir,
    $OutputDir,
    $TemplateDir,
    $TargetAudience
)

$IncludePath = Join-Path $PSScriptRoot "AzureDevOpsWikiToDocFxInclude.ps1"
. $IncludePath

Copy-DevOpsWikiToDocFx -InputDir $InputDir -OutputDir $OutputDir -TemplateDir $TemplateDir -TargetAudience $TargetAudience