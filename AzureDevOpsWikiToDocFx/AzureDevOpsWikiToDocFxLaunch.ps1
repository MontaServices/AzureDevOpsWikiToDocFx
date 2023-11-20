param (
    $InputDir,
    $OutputDir,
    $TemplateDir,
    $TargetAudience,
    $AudienceKeywords,
    $ReplaceOutput, 
    $RepoUrlWithPat
)

$AudienceKeywordsParsed = @()
$AudienceKeywordsSplitted = $AudienceKeywords.Split(",")
foreach ($AudienceKeywordSplit in $AudienceKeywordsSplitted) {
    $AudienceKeywordSplit = $AudienceKeywordSplit.Trim()
    $AudienceKeywordsParsed += $AudienceKeywordSplit
}

$IncludePath = Join-Path $PSScriptRoot "AzureDevOpsWikiToDocFxInclude.ps1"
. $IncludePath

Copy-DevOpsWikiToDocFx -InputDir $InputDir -OutputDir $OutputDir -TemplateDir $TemplateDir -TargetAudience $TargetAudience -AudienceKeywords $AudienceKeywordsParsed -ReplaceOutput $ReplaceOutput -RepoUrlWithPat $RepoUrlWithPat