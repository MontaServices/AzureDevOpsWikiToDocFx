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

$AllMarkers = @($TocMarker, $SpecialsMarker, $SpecialsStartMarker, $SpecialsEndMarker)

#### Functions 

# Function to loop recursivly trough an Azure Devops wiki file structure to copy files to a DocFX file structure and fill a TOC file
function Copy-Tree {
  param (
    [string]$InputBaseDirectory,
    [string]$OutputBaseDirectory,
    [ref]$TocFileString,
    [string[]]$TocSubdirectories,
    [string]$TargetAudience,
    [string[]]$AudienceKeywords
  )

  if ($null -eq $TocSubdirectories) {
    $TocSubdirectories = @()
  }

  # Register files from the .order file in the TOC file and copy .md file to the right location
  $InputDirCurrent = Join-Path $InputDir $InputBaseDirectory
  foreach($TocSubDirectory in $TocSubdirectories) {
    $InputDirCurrent = Join-Path $InputDirCurrent $TocSubDirectory
  }
  
  $SubDirectoryOrderFile = Get-ChildItem -Path $InputDirCurrent | Where-Object Name -eq $OrderFileName
  if ($SubDirectoryOrderFile.Count -gt 0) {
    if ($SubDirectoryOrderFile.Count -gt 1) {
      Throw "Multiple $OrderFileName files in directory $OrderFileLine"
    }

    # Get lines in .order file
    $SubdirectoryOrderFileLines = Get-Content -Path $SubDirectoryOrderFile.FullName
    if ($SubdirectoryOrderFileLines.Count -gt 0) {

      if ($TocSubdirectories.Count -gt 0) {
        $TocFileString.Value += "  " * ($TocSubdirectories.Count-1) + "  items:`n";
      }

      foreach($SubdirectoryOrderFileLine in $SubdirectoryOrderFileLines) {        
        # Create directory and md file paths
        $SubdirectoryOrderLineFileName = "$SubdirectoryOrderFileLine$MarkdownExtension"

        $NewDir = Join-Path $OutputDir $OutputBaseDirectory
        foreach($TocSubDirectory in $TocSubdirectories) {
          $NewDir = Join-Path $NewDir $TocSubDirectory
        }
        $SubdirectoryOrderFileLineFileName = Format-PageFileName $SubdirectoryOrderFileLine
        $NewDir = Join-Path $NewDir $SubdirectoryOrderFileLineFileName

        $CopyItemDestination = Join-Path $NewDir "index.md"
        $CopyItemPath = Join-Path $InputDir $InputBaseDirectory
        foreach($TocSubDirectory in $TocSubdirectories) {
          $CopyItemPath = Join-Path $CopyItemPath $TocSubDirectory
        }
        $CopyItemPath = Join-Path $CopyItemPath $SubdirectoryOrderLineFileName

        # write md file
        $Name = Format-PageName $SubdirectoryOrderFileLine
        $ContentWritten = Copy-MarkdownFile -Path $CopyItemPath -DestinationDir $NewDir -Destination $CopyItemDestination -Level ($TocSubdirectories.Count + 2)  -TargetAudience $TargetAudience -AudienceKeywords $AudienceKeywords -PageTitle $Name
        
        # If the page has been written (due to audience)
        if ($ContentWritten) {
          # Add to TOC
          $Indent = "  " * $TocSubdirectories.Count
          $TocFileString.Value += "$Indent- name: $Name`n"
          $TocPathItems = $TocSubdirectories.Clone()
          $TocPathItems += $SubdirectoryOrderFileLine
          $TocFileString.Value += "$Indent  href: $($TocPathItems -join "/")/`n"
          $TocFileString.Value += "$Indent  topicHref: $($TocPathItems -join "/")/`n"

          # Check for subdirectory with the same name for subpages
          $SubdirectoryOrderFileLineFormatted = Format-PageFileName $SubdirectoryOrderFileLine
          $SubSubDirectory = Join-Path $InputDirCurrent $SubdirectoryOrderFileLineFormatted
          if (Test-Path -Path $SubSubDirectory -PathType "Container") {
            $NewTocSubdirectories = $TocSubdirectories.Clone()
            $NewTocSubdirectories += $SubdirectoryOrderFileLine
            Copy-Tree -InputBaseDirectory $InputBaseDirectory -OutputBaseDirectory $OutputBaseDirectory -TocFileString ([ref]$SubTocContents) -TocSubdirectories $NewTocSubdirectories -TargetAudience $TargetAudience -AudienceKeywords $AudienceKeywords
          }
        }
      }
    }
  }
}


function Get-SilenceByAudience {
  param (
    [string]$AudienceSpecified,
    [string]$TargetAudience
  )

  $AudienceSpecified = $AudienceSpecified.Trim()

  if ($null -eq $TargetAudience) {
    $TargetAudience = ""
  }
  else {
    $TargetAudience = $TargetAudience.Trim()
  }
  
  if ($TargetAudience.Length -le 0) {
    if ($AudienceSpecified.Length -gt 0) {
      # No target audience, but audience specified -> silence
      return $true
    }
    else {
      # No target audience, no audience specified -> no silence
      return $false
    }
  }
  else {
    if ($AudienceSpecified.Length -le 0) {
      # Target audience, but no audience specified -> silence
      return $true
    }
    else {
      # Target audience, audience specified
      $AudiencesSpecified = $AudienceSpecified.Split(',')
      $TargetAudiences = $TargetAudience.Split(',')
      foreach($AudiencesSpecifiedPart in $AudiencesSpecified) {
        $AudiencesSpecifiedPart = $AudiencesSpecifiedPart.Trim()
        foreach($TargetAudiencesPart in $TargetAudiences) {
          $TargetAudiencesPart = $TargetAudiencesPart.Trim()
          if ($AudiencesSpecifiedPart -eq $TargetAudiencesPart) {
            return $false
          }
        }
      }
      return $true
    }
  }
}

# Throw an exception when a page name contains an invalid character
function Format-PageFileName {
  param (
    [string]$PageFileName
  )

  $PageFileName = $PageFileName.Replace("%2D", "-")

  if ($PageFileName.Contains("%")) {
    throw "Invalid page name ${PageFileName}: DocFX does not support special characters"
  }

  return $PageFileName
}

function Format-PageName {
  param (
    [string]$PageName
  )

  $PageName = [System.Web.HTTPUtility]::UrlDecode($PageName).Replace("-", " ")

  return $PageName
}

# Function to copy an Azure Devops wiki file to a DocFX file
function Copy-MarkdownFile {
    param (
        [string]$Path,
        [string]$DestinationDir,
        [string]$Destination,
        [int]$Level,
        [string]$TargetAudience,
        [string[]]$AudienceKeywords,
        [string]$PageTitle
    )

    $SpecialsMarkerStarted = 0
    $SpecialsStartMarkersStartedWithSilencedByAudience = New-Object System.Collections.Stack
    $ContentWritten = $false
    $Silent = $false
    $FirstLineWritten = $false
    $DestinationDirExists = $false
    $AudiencePassedOnFirstLine = $false

    $OrderFileLines = Get-Content -Path (Join-Path $InputDir $OrderFilesFound[0].Name)
    $OrderFileLinesCount = $OrderFileLines.Count

    $MdFilePath = Join-Path $InputDir "$OrderFileLines$MarkdownExtension"
    if ($OrderFileLinesCount -gt 1) {
        $MdFilePath = $Path
    }

    if (-not (Test-Path -Path $MdFilePath -PathType Leaf) -and -not (Test-Path -Path $Path -PathType Leaf)) {
        Write-Host "File not found: $Path, skipping..."
        return $false
    }

    $contentBuilder = [System.Text.StringBuilder]::new()

    foreach ($MdLine in Get-Content -Path $MdFilePath) {
        $MdLine = $MdLine.Trim()
        $SilenceAfterNextLine = $false;
        $DoNotWriteLineIfItsEmpty = $false

        # Loop through each position in the string to process markers
        $Start = 0
        while ($Start -lt $MdLine.Length) {
            # Check for each marker if it's found on this position
            foreach ($Marker in $AllMarkers) {
                if ($MdLine.Length -ge ($Start + ($Marker.Length)) -and $MdLine.Substring($Start, $Marker.Length) -eq $Marker) {
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
                        foreach ($AudienceKeyword in $AudienceKeywords) {
                            if ($PartAfterMarkerTrimmed.StartsWith($AudienceKeyword)) {
                                $PartBeforeMarker = $MdLine.Substring(0, $Start)
                                # Get everything after "Audience:" or "Audience " or "Audience : "
                                $PartAfterAudience = $MdLine.Substring($Start + $Marker.Length + $PartAfterMarker.Length - $PartAfterMarkerTrimmed.Length + $AudienceKeyword.Length);
                                $PartAfterAudienceTrimmed = $PartAfterAudience.TrimStart().TrimStart(":").TrimStart()

                                $RestOfLineSpaceIndex = $PartAfterAudienceTrimmed.IndexOf(" ")

                                # if it ends with a comma, get until the next space
                                while ($RestOfLineSpaceIndex -gt -1 -and $PartAfterAudienceTrimmed[$RestOfLineSpaceIndex - 1] -eq ",") {
                                    $RestOfLineSpaceIndex = $PartAfterAudienceTrimmed.IndexOf(" ", $RestOfLineSpaceIndex + 1)
                                }

                                # For if there is no content after the audience at all, but the end marker immediately
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

                                # check audience
                                $SilenceByAudience = Get-SilenceByAudience -AudienceSpecified $AudienceSpecified -TargetAudience $TargetAudience

                                # If audience is valid, and we were on the start of the file, set the variable
                                if (-not $FirstLineWritten -and -not $SilenceByAudience) {
                                    $AudiencePassedOnFirstLine = $true
                                }

                                # Check if the end marker is on this line
                                $EndMarkerPos = $PartAfterAudienceKeyword.IndexOf($SpecialsEndMarker)

                                # If the end marker is on this line, skip or retain part between markers
                                # Except if we are on the same line, then it counts for the whole file so we skip the end marker
                                if ($EndMarkerPos -gt -1 -and $FirstLineWritten) {
                                    $MdLine = $PartBeforeMarker

                                    # Part between end marker
                                    if (-not $SilenceByAudience) {
                                        $MdLine += $PartAfterAudienceKeyword.Substring(0, $EndMarkerPos)
                                    }

                                    # Part after end marker
                                    $MdLine += $PartAfterAudienceKeyword.Substring($EndMarkerPos + $SpecialsEndMarker.Length)
                                }
                                else {
                                    if ($EndMarkerPos -gt -1) {
                                        $PartAfterAudienceKeyword = $PartAfterAudienceKeyword.Substring($EndMarkerPos + $SpecialsEndMarker.Length)
                                    }

                                    # The end marker is not on this line
                                    if (-not $SilenceByAudience) {
                                        $MdLine = $PartBeforeMarker + $PartAfterAudienceKeyword
                                    }
                                    else {
                                        $MdLine = $PartBeforeMarker
                                        $SilenceAfterNextLine = $true
                                    }
                                    $SpecialsStartMarkersStartedWithSilencedByAudience.Push($SilenceAfterNextLine)
                                }

                                break # if an audience marker is found after the [[, do not search for other markers
                            }
                        }
                    }
                    elseif ($Marker -eq $SpecialsEndMarker) { # ]]
                        # if we are in a start marker [[
                        if ($SpecialsStartMarkersStartedWithSilencedByAudience.Count -gt 0) {
                            $SpecialsStartMarkersStartedWithSilencedByAudience.Pop() | Out-Null

                            if ($Silent -eq $true) {
                                $PartAfterMarker = $MdLine.Substring($Start + $Marker.Length).TrimStart()
                                $MdLine = $PartAfterMarker

                                # Check if we are still in a marker that is silenced
                                $AreWeStillSilenced = $false
                                foreach ($SilencedByMarker in $SpecialsStartMarkersStartedWithSilencedByAudience) {
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

        # change h1 to h2, h2 to h3, and so on
        if ($MdLine.StartsWith("#")) {
            $MdLine = "#" + $MdLine
        }

        # change images with a specified width so DocFX understands them
        if ($MdLine.Contains("![")) {
            $RegexImageMatch = [regex]::Match($MdLine, "!\[.*\]\((.+) =([0-9]+)x([0-9]*)\)")

            if ($RegexImageMatch.Success) {
                $MdLineBefore = $MdLine.Substring(0, $RegexImageMatch.Index)
                $MdLineAfter = $MdLine.Substring($RegexImageMatch.Index + $RegexImageMatch.Length)

                $MdLine = $MdLineBefore
                $MdLine += "<img src=""" + $RegexImageMatch.Groups[1] + """"
                $MdLine += " width=""" + $RegexImageMatch.Groups[2] + """"
                if ($RegexImageMatch.Groups[3].Length -gt 0) {
                    $MdLine += " height=""" + $RegexImageMatch.Groups[3] + """"
                }
                $MdLine += " />"
                $MdLine += $MdLineAfter
            }
        }

        # here follow checks if the line should be written
        $WriteLine = $true

        # Don't write empty lines at the start of the file or if it was requested
        if ($MdLine.Length -lt 1) {
            if ($DoNotWriteLineIfItsEmpty -eq $true -or $FirstLineWritten -eq $false) {
                $WriteLine = $false
            }
        }

        if ($Silent) {
            $WriteLine = $false
        }

        # If a TargetAudience is specified, but the content has no audience specified, do not print it
        if ($TargetAudience.Length -gt 0) {
            if (-not $AudiencePassedOnFirstLine) {
                $WriteLine = $false
                $FirstLineWritten = $true # We set this to true because a line would have been written
                # if it was not skipped because of the audience
            }
        }

        # Append the line to the StringBuilder if it's meant to be written
        if ($WriteLine) {
            $contentBuilder.AppendLine($MdLine)
            $ContentWritten = $true
            $FirstLineWritten = $true
        }

        if ($SilenceAfterNextLine -eq $true) {
            $Silent = $true
            $SilenceAfterNextLine = $false
        }
    }

    # Write the content accumulated in the StringBuilder to the destination file
	if ($ContentWritten) {
		# Create the destination directory if it doesn't exist
		if (-not (Test-Path -Path $DestinationDir)) {
			New-Item -ItemType "directory" -Path $DestinationDir | Out-Null
		}

		$contentBuilder.ToString() | Out-File -FilePath $Destination -Encoding UTF8
	}
	return $ContentWritten
}



# Main function of the script
function Copy-DevOpsWikiToDocFx {
  param (
    [string]$InputDir, 
    [string]$OutputDir, 
    [string]$TemplateDir,
    [string]$TargetAudience,
    [string[]]$AudienceKeywords
  )

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

  # Sort audience keywords by longest first
  $AudienceKeywords = $AudienceKeywords | Sort-Object Length -Descending

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

  $HomepageTitle = Format-PageName $OrderFileLines[0]
  Copy-MarkdownFile -Path (Join-Path $InputDir "$($OrderFileLines[0])$MarkdownExtension") -DestinationDir $OutputDir -Destination (Join-Path $OutputDir $DocFxHomepageFilename) -Level 0 -TargetAudience $TargetAudience -AudienceKeywords $AudienceKeywords -PageTitle $HomepageTitle

  # Create TOC file and for the rest of the files in the .order file and copy files to the right directory
  $TocContents = ""
  foreach($OrderFileLine in ($OrderFileLines | Select-Object -Skip 1))
  {
    # Toc file in subdirectory
    $SubTocContents = ""

    # Markdown file in subdirectory    
    $OrderFileLineForDestinationDir = Format-PageFileName $OrderFileLine
    $DestinationDir = Join-Path $OutputDir $OrderFileLineForDestinationDir
    $PageName = Format-PageName $OrderFileLine
    $ContentWritten = Copy-MarkdownFile -Path (Join-Path $InputDir "$OrderFileLine$MarkdownExtension") -DestinationDir $DestinationDir -Destination (Join-Path $DestinationDir $DocFxSectionIntroductionFilename) -Level 1 -TargetAudience $TargetAudience -AudienceKeywords $AudienceKeywords -PageTitle $PageName
    
    # If file was written
    if ($ContentWritten) {
      # Toc
      $TocContents += "- name: $PageName`n"
      $TocContents += "  href: $OrderFileLine/`n"
      $TocContents += "  topicHref: $OrderFileLine/`n"

      # If a directory exists with the name, then it has subpages
      $SubDirectory = Join-Path $InputDir $OrderFileLine
      if (Test-Path -Path $SubDirectory -PathType "Container") {
        Copy-Tree -InputBaseDirectory $OrderFileLine -OutputBaseDirectory $OrderFileLineForDestinationDir -TocFileString ([ref]$SubTocContents) -TargetAudience $TargetAudience -AudienceKeywords $AudienceKeywords
      }
    }
    
    # Write section TOC file
    if ($SubTocContents.Length -gt 0) {
      Set-Content -Path (Join-Path (Join-Path $OutputDir $OrderFileLineForDestinationDir) $DocFxTocFilename) -Value $SubTocContents
    }
  }
  # TOC file schrijven
  if ($TocContents.Length -gt 0) {
    Set-Content -Path (Join-Path $OutputDir $DocFxTocFilename) -Value $TocContents
  }
  $AttachmentsSourcePath = Join-Path $InputDir ".attachments"
  $AttachmentsDestinationPath = Join-Path $OutputDir $AttachmentsDirName
  if (Test-Path -Path $AttachmentsSourcePath -PathType Container) {
	  Copy-Item -Path $AttachmentsSourcePath -Destination $AttachmentsDestinationPath -Recurse
	  } else {
		  Write-Host "No .attachments folder found. Skipping attachment copy."
		  }

  # Copy attachments dir
  
 # Copy-Item -Path (Join-Path $InputDir ".attachments") -Destination (Join-Path $OutputDir $AttachmentsDirName) -Recurse

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
}