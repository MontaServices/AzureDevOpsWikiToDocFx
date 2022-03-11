Describe "AzureDevOpsWikiToDocFx" {
    It "Test markdown" {
        $Path = Join-Path $TestDrive "Input.md"
        $Destination = Join-Path $TestDrive "Output.md"

        $InputFileContents = @"
Dit is een test
"@

        Set-Content -Path $Path -Value $InputFileContents

        Copy-MarkdownFile -Path $Path -Destination $Destination -Level 0

        $Output = Get-Content -Path $Destination

        $Output | Should Be $InputFileContents
    }
}