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

# Constants

$OrderFileName = ".order"
$MarkdownExtension = ".md"
$DocFxHomepageFilename = "index.md"
$DocFxTocFilename = "toc.yml"
$DocFxJsonFilename = "docfx.json"
$DocFxSectionIntroductionFilename = "index.md"
$SpecialsMarker = ":::" # For e.g. Mermaid diagrams
$AttachmentsDirName = "Attachments"

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
    $SubdirectoryOrderFileLines = @(Get-Content -Path $SubDirectoryOrderFile.FullName)
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
        Copy-MarkdownFile -Path $CopyItemPath -Destination $CopyItemDestination -Level ($TocSubdirectories.Count + 2)

        # Check for subdirectory with the same name for subpages
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

# Function to copy an Azure Devops wiki file to a DocFX file
function Copy-MarkdownFile {
  param (
    [string]$Path,
    [string]$Destination,
    [int]$Level
  )

  $ThreeDotsStarted = 0;
  $Silent = $false
  $ContentWritten = $false
  foreach($MdLine in @(Get-Content -Path $Path)) {
    # Process ::: marker for mermaid and private (content to hide)
    if ($MdLine.TrimStart().StartsWith($SpecialsMarker))
    {
      $RestOfLine = $MdLine.Substring(3).Trim();
      if ($RestOfLine.Length -gt 0) {
        if ($RestOfLine -eq "private") {
          $Silent = $true
        }
        else {
          $MdLine = "<div class=`"$RestOfLine`">"
        }
        $ThreeDotsStarted += 1    
      }
      elseif ($ThreeDotsStarted -gt 0) {
        $MdLine = "</div>"
        $ThreeDotsStarted -= 1
      }
    }

    # Process images link path
    $MdLine = $MdLine.Replace("](/.attachments", "](/$AttachmentsDirName")

    # Make absolute links relative
    $RelativePathPrefix = "../" * $Level
    $MdLine = $MdLine.Replace("](/", "]($RelativePathPrefix")

    # Write to destination file
    if ($Silent -eq $false) {
      Add-Content -Path $Destination -Value $MdLine
      $ContentWritten = $true
    }
    elseif ($ThreeDotsStarted -lt 1) {
      $Silent = $false
    }
  }

  if ($ContentWritten -eq $false) {
    Add-Content -Path $Destination -Value "" # Otherwise no file will be created
  }
}

# Search .order file

$OrderFilesFound = Get-ChildItem -Path $InputDir | Where-Object Name -eq $OrderFileName

if ($OrderFilesFound.Count -ne 1) {
  Throw "Input directory does not contain a $OrderFileName file"
}

# Create homepage for first file in de .order file
$OrderFileLines = @(Get-Content -Path (Join-Path $InputDir $OrderFilesFound[0].Name))

if ($OrderFileLines.Count -lt 1) {
  Throw "$OrderFileName file in Input directory is empty"
}

New-Item -ItemType "directory" -Path $OutputDir | Out-Null # create output dir (silent, output to null)

Copy-MarkdownFile -Path (Join-Path $InputDir "$($OrderFileLines[0])$MarkdownExtension") -Destination (Join-Path $OutputDir $DocFxHomepageFilename) -Level 0

# Create TOC file and for the rest of the files in the .order file and copy files to the right directory
$TocContents = ""
foreach($OrderFileLine in ($OrderFileLines))
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
