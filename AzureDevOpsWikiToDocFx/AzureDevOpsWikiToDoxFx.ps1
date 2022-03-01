<#
  .SYNOPSIS
  This script transform Azure DevOps wiki files to a DocFX project
  .DESCRIPTION
  This script transform Azure DevOps wiki files to a DocFX project.
  .PARAMETER InputDir
  The directory where the Azure DevOps wiki files are located.
	.PARAMETER OutputDir
	The directory where the DocFx project files should be written. It should not yet exist.
	.PARAMETER TemplateDir
	Where de DocFX template files are. Required because this needs a modified DocFX template to get it work.
  #>

# Read parameters

param($InputDir, $OutputDir, $TemplateDir)
# TODO target audience

# Setup

$ErrorActionPreference = "Stop" # Stop on first error

# Constants

$OrderFileName = ".order"
$MarkdownExtension = ".md"
$DocFxHomepageFilename = "index.md"
$DocFxTocFilename = "toc.yml"
$DocFxJsonFilename = "docfx.json"
$DocFxSectionIntroductionFilename = "index.md"
$SpecialsMarker = ":::" # For Mermaid diagrams
$MermaidKeyword = "mermaid"
$SpecialsStartMarker = "[[" # For TOC and audience
$SpecialsEndMarker = "]]"
$TocMarker = "[[_TOC_]]"
$AttachmentsDirName = "Attachments"
$AudienceKeywords = $("Audience", "Doelgroep", "Doelgroepen") # TODO parameter

$AllMarkers = @($TocMarker, $SpecialsMarker, $SpecialsStartMarker, $SpecialsEndMarker)
$AudienceKeywords = $AudienceKeywords | Sort-Object Length -Descending # longest first

# Check parameters

if ($null -eq $InputDir) {
  Throw "Parameter InputDir not provided"
}	

if ($null -eq $OutputDir) {
  Throw "Parameter OutputDir not provided"
}

if ($null -eq $TemplateDir) {
  Throw "Parameter TemplateDir not provided"
}

if (Test-Path -Path $OutputDir) {
  Throw "OutputDir already exists"
}

if ((Test-Path -Path $TemplateDir -PathType "Container") -ne $true) {
  throw "TemplateDir does not exist"
}

#####
# Functions
####

# Function to loop recursivly trough an Azure Devops wiki file structure to copy files to a DocFX file structure and fill a TOC file
function Copy-Tree {
  param (
    [string]$BaseDirectory,
    [ref]$TocFileString,
    [string[]]$TocSubdirectories
  )

  if ($null -eq $TocSubdirectories) {
    $TocSubdirectories = @()
  }
  
  # Register files from the .order file in the TOC file and copy .md file to the right location
  $InputDirCurrent = Join-Path $InputDir $BaseDirectory
  foreach($TocSubDirectory in $TocSubdirectories) {
    $InputDirCurrent = Join-Path $InputDirCurrent $TocSubDirectory
  }
  
  $SubDirectoryOrderFile = Get-ChildItem -Path $InputDirCurrent | Where-Object Name -eq $OrderFileName
  if ($SubDirectoryOrderFile.Count -gt 0) {
    if ($SubDirectoryOrderFile.Count -gt 1) {
      Write-Host "Multiple $OrderFileName files in directory $OrderFileLine"
      Exit 1
    }

    # Get lines in .order file
    $SubdirectoryOrderFileLines = Get-Content -Path $SubDirectoryOrderFile.FullName
    if ($SubdirectoryOrderFileLines.Count -gt 0) {

      if ($TocSubdirectories.Count -gt 0) {
        $TocFileString.Value += "  " * ($TocSubdirectories.Count-1) + "  items:`n";
      }

      foreach($SubdirectoryOrderFileLine in $SubdirectoryOrderFileLines) {
        $Indent = "  " * $TocSubdirectories.Count
        $Name = $SubdirectoryOrderFileLine.Replace("-", " ")
        $TocFileString.Value += "$Indent- name: $Name`n"
        $TocPathItems = $TocSubdirectories.Clone()
        $TocPathItems += $SubdirectoryOrderFileLine
        $TocFileString.Value += "$Indent  href: $($TocPathItems -join "/")/`n"
        $TocFileString.Value += "$Indent  topicHref: $($TocPathItems -join "/")/`n"
        
        # Create directory and copy md file
        $SubdirectoryOrderLineFileName = "$SubdirectoryOrderFileLine$MarkdownExtension"

        $NewDir = Join-Path $OutputDir $BaseDirectory
        foreach($TocSubDirectory in $TocSubdirectories) {
          $NewDir = Join-Path $NewDir $TocSubDirectory
        }
        $NewDir = Join-Path $NewDir $SubdirectoryOrderFileLine
        New-Item -ItemType "directory" -Path $NewDir | Out-Null # silent

        $CopyItemDestination = Join-Path $NewDir "index.md"
        $CopyItemPath = Join-Path $InputDir $BaseDirectory
        foreach($TocSubDirectory in $TocSubdirectories) {
          $CopyItemPath = Join-Path $CopyItemPath $TocSubDirectory
        }
        $CopyItemPath = Join-Path $CopyItemPath $SubdirectoryOrderLineFileName
        $ContentWritten = Copy-MarkdownFile -Path $CopyItemPath -Destination $CopyItemDestination -Level ($TocSubdirectories.Count + 2)

        # Check for subdirectory with the same name for subpages
        # Only if this page has been written
        if ($ContentWritten) {
          $SubSubDirectory = Join-Path $InputDirCurrent $SubdirectoryOrderFileLine
          if (Test-Path -Path $SubSubDirectory -PathType "Container") {
            $NewTocSubdirectories = $TocSubdirectories.Clone()
            $NewTocSubdirectories += $SubdirectoryOrderFileLine
            Copy-Tree -BaseDirectory $BaseDirectory -TocFileString ([ref]$SubTocContents) -TocSubdirectories $NewTocSubdirectories
          }
        }
      }
    }
  }
}

# Function to copy an Azure Devops wiki file to a DocFX file
function Copy-MarkdownFile {
  param (
    [string]$Path,
    [string]$Destination,
    [int]$Level
  )

  $SpecialsMarkerStarted = 0
  $SpecialsStartMarkersStartedWithSilencedByAudience = New-Object System.Collections.Stack
  $ContentWritten = $false
  $Silent = $false
  $FirstLineWritten = $false

  # Process each line in the file
  foreach($MdLine in Get-Content -Path $Path) {
    $MdLine = $MdLine.Trim()
    $SilenceAfterNextLine = $false;
    $DoNotWriteLineIfItsEmpty = $false

    # Loop trough each position in the string to process markers
    $Start = 0
    while ($Start -lt $MdLine.Length) {
      # Check for each marker if its found on this position
      foreach($Marker in $AllMarkers) {
        if ($MdLine.Length -ge ($Start+($Marker.Length)) -and $MdLine.Substring($Start, $Marker.Length) -eq $Marker) {
          # A marker is found

          if ($Marker -eq $TocMarker) { # [[_TOC_]]
            # Remove TOC marker from line
            $PartBeforeMarker = $MdLine.Substring(0, $Start)
            $PartAfterMarker = $MdLine.Substring($Start + $Marker.Length)
            $PartAfterMarkerTrimmed = $PartAfterMarker.TrimStart()
            $MdLine = $PartBeforeMarker + $PartAfterMarkerTrimmed
            $DoNotWriteLineIfItsEmpty = $true # Do not write the line if the TOC was the only thing on this line
          }
          elseif ($Marker -eq $SpecialsStartMarker) { # [[
            $PartAfterMarker = $MdLine.Substring($Start + $Marker.Length)
            $PartAfterMarkerTrimmed = $PartAfterMarker.TrimStart()
            # turn "[[ Audience" into ...
            foreach($AudienceKeyword in $AudienceKeywords) {
              if ($PartAfterMarkerTrimmed.StartsWith($AudienceKeyword)) {
                $PartBeforeMarker = $MdLine.Substring(0, $Start)
                # Get everything after "Audience:" or "Audience " or "Audience : "
                $PartAfterAudience = $MdLine.Substring($Start + $Marker.Length + $PartAfterMarker.Length - $PartAfterMarkerTrimmed.Length + $AudienceKeyword.Length);
                $PartAfterAudienceTrimmed = $PartAfterAudience.TrimStart().TrimStart(":").TrimStart()
                
                $AudienceSpecified
                $PartAfterAudienceKeyword

                $RestOfLineSpaceIndex = $PartAfterAudienceTrimmed.IndexOf(" ")
                
                # if it ends with a comma, get until the next space
                while ($RestOfLineSpaceIndex -gt -1 -and $PartAfterAudienceTrimmed[$RestOfLineSpaceIndex-1] -eq ",") {
                  $RestOfLineSpaceIndex = $PartAfterAudienceTrimmed.IndexOf(" ", $RestOfLineSpaceIndex+1)
                }

                # For if there is no content after the audience at all, but the endmarker immediately
                $RestOfLineEndMarkerIndex = $PartAfterAudienceTrimmed.IndexOf($SpecialsEndMarker)
                if ($RestOfLineEndMarkerIndex -gt -1 -and ($RestOfLineEndMarkerIndex -lt $RestOfLineSpaceIndex -or $RestOfLineSpaceIndex -lt 0)) {
                  $AudienceSpecified = $PartAfterAudienceTrimmed.Substring(0, $RestOfLineEndMarkerIndex)
                  $PartAfterAudienceKeyword = $PartAfterAudienceTrimmed.Substring($RestOfLineEndMarkerIndex) # After the space
                }
                elseif ($RestOfLineSpaceIndex -lt 0) {
                  $AudienceSpecified = $PartAfterAudienceTrimmed
                  $PartAfterAudienceKeyword = ""
                }
                else {
                  $AudienceSpecified = $PartAfterAudienceTrimmed.Substring(0, $RestOfLineSpaceIndex)
                  $PartAfterAudienceKeyword = $PartAfterAudienceTrimmed.Substring($RestOfLineSpaceIndex + 1) # After the space
                }

                # TODO check audience

                # Check if the end marker is on this line
                $EndMarkerPos = $PartAfterAudienceKeyword.IndexOf($SpecialsEndMarker)
                if ($EndMarkerPos -gt -1) { 
                  # The end marker is this line
                  $MdLine = $PartBeforeMarker + $PartAfterAudienceKeyword.Substring($EndMarkerPos + $SpecialsEndMarker.Length).TrimStart()
                }
                else {
                  # The end marker is not on this line
                  $MdLine = $PartBeforeMarker
                  $SilenceAfterNextLine = $true
                  $SpecialsStartMarkersStartedWithSilencedByAudience.Push($SilenceAfterNextLine)
                }

                break # if an audience marker is found after the [[, do not search for others
              }
            }
          }
          elseif ($Marker -eq $SpecialsEndMarker) { # ]]
            # if we are in a start marker [[
            if ($SpecialsStartMarkersStartedWithSilencedByAudience.Count -gt 0) {

              $SpecialsStartMarkersStartedWithSilencedByAudience.Pop()

              if ($Silent -eq $true)
              {
                $PartAfterMarker = $MdLine.Substring($Start + $Marker.Length).TrimStart()
                $MdLine = $PartAfterMarker
                
                # Check if we are still in a marker which is silenced
                $AreWeStillSilenced = $false
                foreach($SilencedByMarker in $SpecialsStartMarkersStartedWithSilencedByAudience) {
                  if ($SilencedByMarker -eq $true) {
                    $AreWeStillSilenced = $true
                    break
                  }
                }
  
                if ($AreWeStillSilenced -eq $false) {
                  $Silent = $false
                }

              }
              else {
                $PartBeforeMarker = $MdLine.Substring(0, $Start)
                $PartAfterMarker = $MdLine.Substring($Start + $Marker.Length).TrimStart()
                $MdLine = $PartBeforeMarker + $PartAfterMarker               
              }              
            }
          }
          elseif ($Marker -eq $SpecialsMarker) { # :::
            $PartAfterMarker = $MdLine.Substring($Start + $Marker.Length)
            $PartAfterMarkerTrimmed = $PartAfterMarker.TrimStart()
            # turn "::: mermaid" into a div
            if ($PartAfterMarkerTrimmed.StartsWith($MermaidKeyword)) {
              $PartBeforeMarker = $MdLine.Substring(0, $Start)
              $PartAfterMermaid = $MdLine.Substring($Start + $Marker.Length + $PartAfterMarker.Length - $PartAfterMarkerTrimmed.Length + $MermaidKeyword.Length);
              $PartToInsert = "<div class=`"$MermaidKeyword`">"
              $MdLine = $PartBeforeMarker + $PartToInsert + $PartAfterMermaid
              $Start += $PartToInsert.Length
              $SpecialsMarkerStarted += 1
            }
            # turn ":::" into an end div (if a div was started)
            elseif ($SpecialsMarkerStarted -gt 0) {
              $PartBeforeMarker = $MdLine.Substring(0, $Start)
              $PartToInsert = "</div>"
              $MdLine = $PartBeforeMarker + $PartToInsert + $PartAfterMarker
              $Start += $PartToInsert.Length
              $SpecialsMarkerStarted -= 1
            }
          }
        }
      }

      $Start += 1
    }

    # Process images link path
    $MdLine = $MdLine.Replace("](/.attachments", "](/$AttachmentsDirName")

    # Make absolute links relative
    $RelativePathPrefix = "../" * $Level
    $MdLine = $MdLine.Replace("](/", "]($RelativePathPrefix")

    # Don't write empty lines at the start of the file or if it was requested
    if ($MdLine.Length -lt 1) {
      if ($DoNotWriteLineIfItsEmpty -eq $true -or $FirstLineWritten -eq $false) {
        continue
      }
    }

    # Write to destination file
    if ($Silent -ne $true) {
      Add-Content -Path $Destination -Value $MdLine
      $ContentWritten = $true
      $FirstLineWritten = $true
    }

    if ($SilenceAfterNextLine -eq $true) {
      $Silent = $true
      $SilenceAfterNextLine = $false
    }
  }

  return $ContentWritten
}

#####
# Script starts here
####

# Search .order file

$OrderFilesFound = Get-ChildItem -Path $InputDir | Where-Object Name -eq $OrderFileName

if ($OrderFilesFound.Count -ne 1) {
  Throw "Input directory does not contain a $OrderFileName file"
}

# Create homepage for first file in de .order file
$OrderFileLines = Get-Content -Path (Join-Path $InputDir $OrderFilesFound[0].Name)

if ($OrderFileLines.Count -lt 1) {
  Throw "$OrderFileName file in Input directory is empty"
}

New-Item -ItemType "directory" -Path $OutputDir | Out-Null # create output dir (silent, output to null)

Copy-MarkdownFile -Path (Join-Path $InputDir "$($OrderFileLines[0])$MarkdownExtension") -Destination (Join-Path $OutputDir $DocFxHomepageFilename) -Level 0

# Create TOC file and for the rest of the files in the .order file and copy files to the right directory
$TocContents = ""
foreach($OrderFileLine in ($OrderFileLines | Select-Object -Skip 1))
{
  $TocContents += "- name: $OrderFileLine`n"
  $TocContents += "  href: $OrderFileLine/`n"
  $TocContents += "  topicHref: $OrderFileLine/`n"

  # subdirectory    
  New-Item -ItemType "directory" -Path (Join-Path $OutputDir $OrderFileLine) | Out-Null # silent

  # Toc file in subdirectory
  $SubTocContents = ""

  # Markdown file in subdirectory
  Copy-MarkdownFile -Path (Join-Path $InputDir "$OrderFileLine$MarkdownExtension") -Destination (Join-Path (Join-Path $OutputDir $OrderFileLine) $DocFxSectionIntroductionFilename) -Level 1

  # If a directory exists with the name, then it has subitems
  $SubDirectory = Join-Path $InputDir $OrderFileLine
  if (Test-Path -Path $SubDirectory -PathType "Container") {
    Copy-Tree -BaseDirectory $OrderFileLine -TocFileString ([ref]$SubTocContents)
  }
  
  # Write section TOC file
  Set-Content -Path (Join-Path (Join-Path $OutputDir $OrderFileLine) $DocFxTocFilename) -Value $SubTocContents
}
# TOC file schrijven
Set-Content -Path (Join-Path $OutputDir $DocFxTocFilename) -Value $TocContents

# Copy attachments dir
Copy-Item -Path (Join-Path $InputDir ".attachments") -Destination (Join-Path $OutputDir $AttachmentsDirName) -Recurse

# Copy template dir
$DocFxTemplateDirName = "docfx_template"
Copy-Item -Path $TemplateDir -Destination (Join-Path $OutputDir $DocFxTemplateDirName) -Recurse

# create docfx.json
$TemplateDirJson = ConvertTo-Json $DocFxTemplateDirName

$DocFxJson = @"
{
    "build": {
      "content": [
        {
          "files": [
            "**.md",
            "**/toc.yml",
            "toc.yml",
            "*.md"
          ]
        }
      ],
      "resource": [
        {
          "files": [
            "Attachments/**"
          ]
        }
      ],
      "dest": "_site",
      "globalMetadataFiles": [],
      "fileMetadataFiles": [],
      "template": [
        ${TemplateDirJson}
      ],
      "postProcessors": [ "ExtractSearchIndex" ],
      "markdownEngineName": "markdig",
      "noLangKeyword": false,
      "keepFileLink": false,
      "cleanupCacheHistory": false,
      "disableGitFeatures": true
    }
  }
"@

Set-Content -Path (Join-Path $OutputDir $DocFxJsonFilename) -Value $DocFxJson 

Exit 0
