# Setup

$ErrorActionPreference = "Stop" # Stop on first error

# Constants

$OrderFileName = ".order"
$MarkdownExtension = ".md"
$DocFxHomepageFilename = "index.md"
$DocFxTocFilename = "toc.yml"
$DocFxJsonFilename = "docfx.json"
$DocFxSectionIntroductionFilename = "index.md"
$SpecialsMarker = ":::"
$AttachmentsDirName = "Attachments"

#### Functions 

# Function to loop recursivly trough an Azure Devops wiki file structure to copy files to a DocFX file structure and fill a TOC file
function Copy-Tree {
  param (
    [string]$InputBaseDirectory,
    [string]$OutputBaseDirectory,
    [ref]$TocFileString,
    [string[]]$TocSubdirectories,
    [System.Collections.Generic.List[string]]$AttachmentPaths
  )

  if ($null -eq $TocSubdirectories) {
    $TocSubdirectories = @()
  }

  # Register files from the .order file in the TOC file and copy .md file to the right location
  $InputDirRel = $InputBaseDirectory
  foreach($TocSubDirectory in $TocSubdirectories) {
    $InputDirRel = Join-Path $InputDirRel $TocSubDirectory
  }
  Write-Host "Processing directory: $InputDirRel"

  $InputDirCurrent = Join-Path $InputDir $InputDirRel
  
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

        $CopyItemPathRel = $InputBaseDirectory
        foreach($TocSubDirectory in $TocSubdirectories) {
          $CopyItemPathRel = Join-Path $CopyItemPathRel $TocSubDirectory
        }
        $CopyItemPathRel = Join-Path $CopyItemPathRel $SubdirectoryOrderLineFileName
        $CopyItemPath = Join-Path $InputDir $CopyItemPathRel

        # write md file
        Write-Host "Processing page: $CopyItemPathRel"
        $Name = Format-PageName $SubdirectoryOrderFileLine
        $ContentWritten = Copy-MarkdownFile -Path $CopyItemPath -DestinationDir $NewDir -Destination $CopyItemDestination -Level ($TocSubdirectories.Count + 2) -PageTitle $Name -AttachmentPaths $AttachmentPaths
        
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
            Copy-Tree -InputBaseDirectory $InputBaseDirectory -OutputBaseDirectory $OutputBaseDirectory -TocFileString ([ref]$SubTocContents) -TocSubdirectories $NewTocSubdirectories -AttachmentPaths $AttachmentPaths
          }
        }
      }
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
    [string]$PageTitle,
    [System.Collections.Generic.List[string]]$AttachmentPaths
  )

  $ContentWritten = $false
  $SilencedByPrivate = $false
  $FirstLineWritten = $false
  $DestinationDirExists = $false

  # Process each line in the file
  foreach($MdLine in Get-Content -Path $Path) {
    if ($ThreeDotsStarted -lt 1 -and $SilencedByPrivate) {
      $SilencedByPrivate = $false
    }

    # Remove Azure Devops wiki specials not supported by DocFX
    $MdLine = $MdLine.Replace("[[_TOC_]]", "")
    $MdLine = $MdLine.Replace("[[_TOSP_]]", "")

    $MdLine = $MdLine.Trim()

    # Process ::: marker for mermaid and private (content to hide)
    if ($MdLine.StartsWith($SpecialsMarker))
    {
      $RestOfLine = $MdLine.Substring(3).Trim();
      if ($RestOfLine.Length -gt 0) {
        if ($RestOfLine -eq "private") {
          $SilencedByPrivate = $true
        }
        else {
          $MdLine = "<div class=`"$RestOfLine`">"
        }
        $ThreeDotsStarted += 1    
      }
      elseif ($ThreeDotsStarted -gt 0) {
        if ($SilencedByPrivate) {
          $MdLine = "" # to not print the dots
        }
        else {
          $MdLine = "</div>"
        }
        $ThreeDotsStarted -= 1
      }
    }

    # change h1 to h2, h2 to h3, and so on
    if ($MdLine.StartsWith("#"))
    {
      $MdLine = "#" + $MdLine 
    }

    $MdLine = Format-MdLineAttachments $MdLine $Level $AttachmentPaths

    # here follow checks if the line should be written
    $WriteLine = $true

    # Don't write empty lines at the start of the file or if it was requested
    if ($MdLine.Length -lt 1) {
      if ($FirstLineWritten -eq $false) {
        $WriteLine = $false
      }
    }

    if ($SilencedByPrivate) {
      $WriteLine = $false
    }

    # Write to destination file
    if ($WriteLine) {
      # Check if destination dir
      if ($DestinationDirExists -ne $true) {
        if ((Test-Path -Path $DestinationDir) -ne $true) {
          New-Item -ItemType "directory" -Path $DestinationDir | Out-Null # silent
        }
        $DestinationDirExists = $true
      }

      # if this is the first line, add the title first
      if (-not $FirstLineWritten) {
        if ($null -ne $PageTitle) {
          if ($PageTitle.Length -gt 0) {
            Add-Content -Path $Destination -Value "# $PageTitle"
            Add-Content -Path $Destination -Value ""
          }
        }
      }

      # Write the line
      Add-Content -Path $Destination -Value $MdLine
      $ContentWritten = $true
      $FirstLineWritten = $true
    }
  }

  return $ContentWritten
}

function Format-MdLineAttachments {
  param(
    [string]$MdLine,
    [int]$Level,
    [System.Collections.Generic.List[string]]$AttachmentPaths
    )  

    # Find attachments and replace directory name.
    # Regex uses 'balancing groups' to match balancing parenthesis in the attachment path: https://stackoverflow.com/a/7899205
    # Allows for image size syntax (IMAGE_URL =WIDTHxHEIGHT): https://learn.microsoft.com/en-us/azure/devops/project/wiki/markdown-guidance?view=azure-devops#images
    $AttachmentsMatches = $MdLine | Select-String -Pattern "\]\(/(\.attachments)/(((?:[^()]|(?<open>\())|(?<-open>\)))+?)( =.*?)?(?(open)(?!))\)" -AllMatches
    $Drift = 0
    foreach ($AttachmentMatch in $AttachmentsMatches.Matches) {
      # replace group 1 (.attachments)
      $MdLine = $MdLine.Remove($AttachmentMatch.Groups[1].Index + $Drift, $AttachmentMatch.Groups[1].Length)
      $MdLine = $MdLine.Insert($AttachmentMatch.Groups[1].Index + $Drift, $AttachmentsDirName)
      $Drift += $AttachmentsDirName.Length - $AttachmentMatch.Groups[1].Length
      
      # group 2 is attachment path
      $AttachmentPath = $AttachmentMatch.Groups[2].Value
      $AttachmentPathParts = @( $AttachmentPath.Split('/') | ForEach-Object { [uri]::UnescapeDataString($_) } )

      $AttachmentPath = $AttachmentPathParts[0]
      foreach($NextAttachmentPathPart in $AttachmentPathParts | Select-Object -Skip 1) {
        $AttachmentPath = Join-Path $AttachmentPath $NextAttachmentPathPart
      }

      $AttachmentPaths.Add($AttachmentPath)
    }

    # Make absolute links relative
    $RelativePathPrefix = "../" * $Level
    $MdLine = $MdLine.Replace("](/", "]($RelativePathPrefix")

    # change images with a specified width so DocFX understands them
    $RegexImageSizeMatch = [regex]::Match($MdLine, "!\[.*\]\((.+) =([0-9]+)x([0-9]*)\)")
    if ($RegexImageSizeMatch.Success)
    {
      $MdLineBefore = $MdLine.Substring(0, $RegexImageSizeMatch.Index)
      $MdLineAfter = $MdLine.Substring($RegexImageSizeMatch.Index + $RegexImageSizeMatch.Length)

      $MdLine = $MdLineBefore
      $MdLine += "<img src=""" + $RegexImageSizeMatch.Groups[1] + """"
      $MdLine += " width=""" + $RegexImageSizeMatch.Groups[2] + """"
      if ($RegexImageSizeMatch.Groups[3].Length -gt 0) {
        $MdLine += " height=""" + $RegexImageSizeMatch.Groups[3] + """"
      }
      $MdLine += " />"
      $MdLine += $MdLineAfter
    }

    return $MdLine
}

# Main function of the script
function Copy-DevOpsWikiToDocFx {
  param (
    [string]$InputDir, 
    [string]$OutputDir, 
    [string]$TemplateDir
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

  # Search .order file
  $OrderFilesFound = Get-ChildItem -Path $InputDir | Where-Object Name -eq $OrderFileName

  if ($OrderFilesFound.Count -ne 1) {
    Throw "Input directory does not contain a $OrderFileName file"
  }

  $OrderFileLines = Get-Content -Path (Join-Path $InputDir $OrderFilesFound[0].Name)

  if ($OrderFileLines.Count -lt 1) {
    Throw "$OrderFileName file in Input directory is empty"
  }

  New-Item -ItemType "directory" -Path $OutputDir | Out-Null # create output dir (silent, output to null)

  $AttachmentPaths = [System.Collections.Generic.List[string]]::new()

  # Create homepage for first file in de .order file
  Write-Host "Processing homepage: ${OrderFileLines[0]}"
  $HomepageTitle = Format-PageName $OrderFileLines[0]
  Copy-MarkdownFile -Path (Join-Path $InputDir "$($OrderFileLines[0])$MarkdownExtension") -DestinationDir $OutputDir -Destination (Join-Path $OutputDir $DocFxHomepageFilename) -Level 0 -PageTitle $HomepageTitle -AttachmentPaths $AttachmentPaths > $null

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
    Write-Host "Processing page: $PageName"
    $ContentWritten = Copy-MarkdownFile -Path (Join-Path $InputDir "$OrderFileLine$MarkdownExtension") -DestinationDir $DestinationDir -Destination (Join-Path $DestinationDir $DocFxSectionIntroductionFilename) -Level 1 -PageTitle $PageName -AttachmentPaths $AttachmentPaths
    
    # If file was written
    if ($ContentWritten) {
      # Toc
      $TocContents += "- name: $PageName`n"
      $TocContents += "  href: $OrderFileLine/`n"
      $TocContents += "  topicHref: $OrderFileLine/`n"

      # If a directory exists with the name, then it has subpages
      $SubDirectory = Join-Path $InputDir $OrderFileLine
      if (Test-Path -Path $SubDirectory -PathType "Container") {
        Copy-Tree -InputBaseDirectory $OrderFileLine -OutputBaseDirectory $OrderFileLineForDestinationDir -TocFileString ([ref]$SubTocContents) -AttachmentPaths $AttachmentPaths
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

  # If attachments found...
  $AttachmentPathsCount = $AttachmentPaths.Count
  if ($AttachmentPathsCount -gt 0) {
    # Create attachments directory in destination
    $AttachmentsDestDir = Join-Path $OutputDir $AttachmentsDirName
    New-Item -Path $AttachmentsDestDir -ItemType "directory" > $null

    # Copy attachment files
    $AttachmentIncrement = 0
    foreach ($AttachmentPath in $AttachmentPaths) {
      $AttachmentIncrement += 1
      Write-Host "Copying attachment ($AttachmentIncrement/$AttachmentPathsCount): $AttachmentPath" 
      $AttachmentSourcePath = Join-Path $InputDir (Join-Path ".attachments" $AttachmentPath)
      $AttachmentDestPath = Join-Path $AttachmentsDestDir $AttachmentPath
    
      # If the attachment path has a directory, create if it not exists.
      $AttachmentPathDir = Split-Path $AttachmentPath
      if ($AttachmentPathDir) {
        $AttachmentPathDirFull = Join-Path $OutputDir (Join-Path $AttachmentsDirName $AttachmentPathDir)
        if (-not (Test-Path $AttachmentPathDirFull)) {
          New-Item -Path $AttachmentPathDirFull -ItemType "directory" > $null
        }
      }
    
      Copy-Item -Path $AttachmentSourcePath -Destination $AttachmentDestPath
    }
  }

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