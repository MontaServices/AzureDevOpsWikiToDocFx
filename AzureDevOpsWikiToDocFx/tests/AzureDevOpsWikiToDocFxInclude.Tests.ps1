Describe "AzureDevOpsWikiToDocFx" {
    BeforeAll { 
        $IncludePath = Join-Path $PSScriptRoot (Join-Path ".." "AzureDevOpsWikiToDocFxInclude.ps1")
        . $IncludePath

        # Helper function for testing files
        function Test-CopyMarkdownFile {
            param(
                [string]$InputFileContents, 
                [bool]$ExpectedContentWritten,
                [string]$ExpectedOutput
            )
            
            $Path = Join-Path $TestDrive "Input.md"
            $Destination = Join-Path $TestDrive "Output.md"
            
            Set-Content -Path $Path -Value $InputFileContents
            Set-Content -Path $Destination -Value "" -NoNewline
    
            $ContentWritten = Copy-MarkdownFile -Path $Path -DestinationDir $TestDrive -Destination $Destination -Level 0
            $ContentWritten | Should BeExactly $ExpectedContentWritten
    
            if ($ContentWritten) {
                $Output = Get-Content -Path $Destination -Raw
        
                $Output | Should Be $ExpectedOutput
            }
        }
    }

    Context "Test Copy-MarkdownFile" {

        It "Part of the file marked as private" {
            $InputFileContents = @"
Test before
:::private
This should be hidden
:::
Test after
"@

            $ExpectedOutput = @"
Test before
Test after

"@
            $ExpectedContentWritten = $true

            Test-CopyMarkdownFile $InputFileContents $ExpectedContentWritten $ExpectedOutput
        }

        It "Nested private" {
            $InputFileContents = @"
Test before
:::private
This should be hidden
::: private
Nested private, should also be hidden
:::
BElow the nested, should also be hidden
:::
Test after
"@

            $ExpectedOutput = @"
Test before
Test after

"@
            $ExpectedContentWritten = $true

            Test-CopyMarkdownFile $InputFileContents $ExpectedContentWritten $ExpectedOutput
        }

        It "File completely marked as private at start" {
            $InputFileContents = @"
::: private

This should be hidden
"@

            $ExpectedContentWritten = $false

            Test-CopyMarkdownFile $InputFileContents $ExpectedContentWritten
        }

        It "Mermaid replaced by div" {
            $InputFileContents = @"
Test before
::: mermaid
This should be hidden
:::
Test after
"@

            $ExpectedOutput = @"
Test before
<div class="mermaid">
This should be hidden
</div>
Test after

"@
            $ExpectedContentWritten = $true

            Test-CopyMarkdownFile $InputFileContents $ExpectedContentWritten $ExpectedOutput
        }
    }
}