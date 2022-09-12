Describe "AzureDevOpsWikiToDocFx" {
    BeforeAll { 
        $IncludePath = Join-Path $PSScriptRoot (Join-Path ".." "AzureDevOpsWikiToDocFxInclude.ps1")
        . $IncludePath
    }

    Context "Get-SilenceByAudience" {

        It "No audience specified, none targeted" {
            $AudienceSpecified = ""
            $TargetAudience = ""
            $Silence = Get-SilenceByAudience -AudienceSpecified $AudienceSpecified -TargetAudience $TargetAudience
            $Silence | Should Be $false
        }
        
        It "Audience specified, none targeted" {
            $AudienceSpecified = "Customers"
            $TargetAudience = ""
            $Silence = Get-SilenceByAudience -AudienceSpecified $AudienceSpecified -TargetAudience $TargetAudience
            $Silence | Should Be $true
        }
        
        It "Audience specified and targeted" {
            $AudienceSpecified = "Customers"
            $TargetAudience = "Customers"
            $Silence = Get-SilenceByAudience -AudienceSpecified $AudienceSpecified -TargetAudience $TargetAudience
            $Silence | Should Be $false
        }
        
        It "Multiple audiences specified, one targeted" {
            $AudienceSpecified = "Customers, Staff"
            $TargetAudience = "Customers"
            $Silence = Get-SilenceByAudience -AudienceSpecified $AudienceSpecified -TargetAudience $TargetAudience
            $Silence | Should Be $false
        }
        
        It "Multiple audiences specified, none targeted" {
            $AudienceSpecified = "Customers, Staff"
            $TargetAudience = "Hank"
            $Silence = Get-SilenceByAudience -AudienceSpecified $AudienceSpecified -TargetAudience $TargetAudience
            $Silence | Should Be $true
        }
        
        It "Multiple audiences specified (other syntax), one targeted" {
            $AudienceSpecified = " Customers,Staff "
            $TargetAudience = "Staff"
            $Silence = Get-SilenceByAudience -AudienceSpecified $AudienceSpecified -TargetAudience $TargetAudience
            $Silence | Should Be $false
        }
        
        It "Multiple audiences specified (other syntax), nothing targeted" {
            $AudienceSpecified = " Customers,Staff "
            $TargetAudience = ""
            $Silence = Get-SilenceByAudience -AudienceSpecified $AudienceSpecified -TargetAudience $TargetAudience
            $Silence | Should Be $true
        }
        
        It "No audiences specified, audience targeted" {
            $AudienceSpecified = ""
            $TargetAudience = "Customers"
            $Silence = Get-SilenceByAudience -AudienceSpecified $AudienceSpecified -TargetAudience $TargetAudience
            $Silence | Should Be $true
        }
        
        It "One audience specified, multiple targeted, match" {
            $AudienceSpecified = "IT"
            $TargetAudience = "Monta, IT"
            $Silence = Get-SilenceByAudience -AudienceSpecified $AudienceSpecified -TargetAudience $TargetAudience
            $Silence | Should Be $false
        }
        
        It "One audience specified, multiple targeted, no match" {
            $AudienceSpecified = "Customers"
            $TargetAudience = "Monta, IT"
            $Silence = Get-SilenceByAudience -AudienceSpecified $AudienceSpecified -TargetAudience $TargetAudience
            $Silence | Should Be $true
        }
        
        It "Multiple audience specified, multiple targeted, match" {
            $AudienceSpecified = "Monta, IT, Customers"
            $TargetAudience = "Monta, IT"
            $Silence = Get-SilenceByAudience -AudienceSpecified $AudienceSpecified -TargetAudience $TargetAudience
            $Silence | Should Be $false
        }
        
        It "Multiple audience specified, multiple targeted, no match" {
            $AudienceSpecified = "Customers, WMS"
            $TargetAudience = "Monta, IT"
            $Silence = Get-SilenceByAudience -AudienceSpecified $AudienceSpecified -TargetAudience $TargetAudience
            $Silence | Should Be $true
        }
    }

    Context "Copy-MarkdownFile with audience" {

        It "Part of the file audienced silence" {
            $Path = Join-Path $TestDrive "Input.md"
            $Destination = Join-Path $TestDrive "Output.md"
    
            $InputFileContents = @"
This is a test
[[Audience Staff,Customers 
This should be hidden
]]
"@

            $ExpectedOutput =  @"
This is a test



"@
    
            Set-Content -Path $Path -Value $InputFileContents
    
            $ContentWritten = Copy-MarkdownFile -Path $Path -DestinationDir $TestDrive -Destination $Destination -Level 0 -AudienceKeywords "Audience"
            $ContentWritten | Should BeExactly $true
    
            $Output = Get-Content -Path $Destination -Raw
    
            $Output | Should Be $ExpectedOutput
        }

        It "Begin of the file audienced silence" {
            $Path = Join-Path $TestDrive "Input2.md"
            $Destination = Join-Path $TestDrive "Output2.md"
    
            $InputFileContents = @"
[[Audience Staff,Customers]]
This is a test
"@
    
            Set-Content -Path $Path -Value $InputFileContents
    
            $ContentWritten = Copy-MarkdownFile -Path $Path -DestinationDir $TestDrive -Destination $Destination -Level 0 -AudienceKeywords "Audience" # No target audience
            $ContentWritten | Should BeExactly $false
    
            $OutputFileExists = Test-Path $Destination
    
            $OutputFileExists | Should Be $false
        }

        It "Target audience beginning of the file valid" {
            $Path = Join-Path $TestDrive "Input3.md"
            $Destination = Join-Path $TestDrive "Output3.md"
    
            $InputFileContents = @"
[[Audience Staff,Customers]]
This is a test
"@
    
            Set-Content -Path $Path -Value $InputFileContents
    
            $ContentWritten = Copy-MarkdownFile -Path $Path -DestinationDir $TestDrive -Destination $Destination -Level 0 -AudienceKeywords "Audience" -TargetAudience "Customers"
            $ContentWritten | Should BeExactly $true
    
            $OutputFileExists = Test-Path $Destination
    
            $OutputFileExists | Should Be $true

            $OutputContents = Get-Content -Path $Destination -Raw
            $OutputContents | Should Be @"
This is a test

"@
        }

        It "Target audience specified and file has no audience" {
            $Path = Join-Path $TestDrive "Input4.md"
            $Destination = Join-Path $TestDrive "Output4.md"
    
            $InputFileContents = @"
This is a test
"@
    
            Set-Content -Path $Path -Value $InputFileContents
    
            $ContentWritten = Copy-MarkdownFile -Path $Path -DestinationDir $TestDrive -Destination $Destination -Level 0 -AudienceKeywords "Audience" -TargetAudience "Customers"
            $ContentWritten | Should BeExactly $false
    
            $OutputFileExists = Test-Path $Destination
    
            $OutputFileExists | Should Be $false
        }

        It "Target audience file and partial hidden" {
            $Path = Join-Path $TestDrive "Input5.md"
            $Destination = Join-Path $TestDrive "Output5.md"
    
            $InputFileContents = @"
[[Doelgroepen: Test1, Test2, Test3, Test4]]

[[Doelgroepen: Test1, Test2, Test3

This is not for public

]]

This however is visible for public
"@
    
            Set-Content -Path $Path -Value $InputFileContents

            $ContentWritten = Copy-MarkdownFile -Path $Path -DestinationDir $TestDrive -Destination $Destination -Level 0 -AudienceKeywords @("Doelgroepen") -TargetAudience "Test4"
            $ContentWritten | Should BeExactly $true

            $OutputFileExists = Test-Path $Destination

            $OutputFileExists | Should Be $true

            $OutputContents = Get-Content -Path $Destination -Raw
            $OutputContents | Should Be @"
This however is visible for public

"@
        }

        It "Target audience file and partial shown" {
            $Path = Join-Path $TestDrive "Input6.md"
            $Destination = Join-Path $TestDrive "Output6.md"
    
            $InputFileContents = @"
[[Doelgroepen: Test1, Test2, Test3, Test4]]

[[Doelgroepen: Test1, Test2, Test3

This is not for public

]]

This however is visible for public
"@
    
            Set-Content -Path $Path -Value $InputFileContents

            $ContentWritten = Copy-MarkdownFile -Path $Path -DestinationDir $TestDrive -Destination $Destination -Level 0 -AudienceKeywords @("Doelgroepen") -TargetAudience "Test1"
            $ContentWritten | Should BeExactly $true

            $OutputFileExists = Test-Path $Destination

            $OutputFileExists | Should Be $true

            $OutputContents = Get-Content -Path $Destination -Raw
            $OutputContents | Should Be @"
This is not for public



This however is visible for public

"@
        }

        It "Audience only matched in part of the file" {
            $Path = Join-Path $TestDrive "Input7.md"
            $Destination = Join-Path $TestDrive "Output7.md"
    
            $InputFileContents = @"
Part before

[[Audiences: Test1,Test2

Part in between

]]

Part after
"@
    
            Set-Content -Path $Path -Value $InputFileContents

            $ContentWritten = Copy-MarkdownFile -Path $Path -DestinationDir $TestDrive -Destination $Destination -Level 0 -AudienceKeywords @("Audiences") -TargetAudience "Test2"
            $ContentWritten | Should BeExactly $false
        }
    }


}