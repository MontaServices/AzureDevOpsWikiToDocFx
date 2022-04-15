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
    
            $ContentWritten = Copy-MarkdownFile -Path $Path -Destination $Destination -Level 0
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
    
            $ContentWritten = Copy-MarkdownFile -Path $Path -Destination $Destination -Level 0
            $ContentWritten | Should BeExactly $false
    
            $OutputFileExists = Test-Path $Destination
    
            $OutputFileExists | Should Be $false
        }
    }


}