Describe "AzureDevOpsWikiToDocFx" {
    BeforeAll { 
        $IncludePath = Join-Path $PSScriptRoot (Join-Path ".." "AzureDevOpsWikiToDocFxInclude.ps1")
        . $IncludePath

        <#
        .SYNOPSIS 
        Helper function for testing Copy-MarkdownFile function.
        #>
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

        It "Format-MdLineAttachments" {
            $AttachmentPaths = [System.Collections.Generic.List[string]]::new()
            $InputMdLine = "![image.png](/.attachments/image-6e3f7ceb-a8c4-4d14-b40d-e43f3c3d7df3 (9).png =200x)![image.png](/.attachments/image/te%20st/image-d349ef4a-da92-403a-a191-a6b82d653b76.png)"
            $ExpectedOutputMdLine = "<img src=`"../../Attachments/image-6e3f7ceb-a8c4-4d14-b40d-e43f3c3d7df3 (9).png`" width=`"200`" />![image.png](../../Attachments/image/te%20st/image-d349ef4a-da92-403a-a191-a6b82d653b76.png)"
            $ActualOutputMdLine = Format-MdLineAttachments -MdLine $InputMdLine -Level 2 -AttachmentPaths $AttachmentPaths
            $ActualOutputMdLine | Should Be $ExpectedOutputMdLine
            $AttachmentPaths.Count | Should Be 2
            $AttachmentPaths[0] | Should Be "image-6e3f7ceb-a8c4-4d14-b40d-e43f3c3d7df3 (9).png"
            $AttachmentPaths[1] | Should Be "image\te st\image-d349ef4a-da92-403a-a191-a6b82d653b76.png"
        }
    }
}