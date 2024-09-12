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

# config

$ErrorActionPreference = "Stop"

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
    [string[]]$TocSubdirectories,
    [System.Collections.Generic.List[string]]$AttachmentPaths
  )

  if ($null -eq $TocSubdirectories) {
    $TocSubdirectories = @()
  }
  
  # Register files from the .order file in the TOC file and copy .md file to the right location
  $InputDirCurrentRel = $BaseDirectory
  foreach($TocSubDirectory in $TocSubdirectories) {
    $InputDirCurrentRel = Join-Path $InputDirCurrentRel $TocSubDirectory
  }
  Write-Host "Processing directory: $InputDirCurrentRel"

  $InputDirCurrent = Join-Path $InputDir $InputDirCurrentRel
  
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
        
        $NewDir = $BaseDirectory
        foreach($TocSubDirectory in $TocSubdirectories) {
          $NewDir = Join-Path $NewDir $TocSubDirectory
        }
        $NewDir = Join-Path $NewDir $SubdirectoryOrderFileLine

        $CopyItemDestination = Join-Path $NewDir "index.md"
        $CopyItemPath = $BaseDirectory
        foreach($TocSubDirectory in $TocSubdirectories) {
          $CopyItemPath = Join-Path $CopyItemPath $TocSubDirectory
        }
        $CopyItemPath = Join-Path $CopyItemPath $SubdirectoryOrderLineFileName
        $ContentWritten = Copy-MarkdownFile -RelPath $CopyItemPath -RelDestination $CopyItemDestination -Level ($TocSubdirectories.Count + 2) -AttachmentPaths $AttachmentPaths

        # Check for subdirectory with the same name for subpages
        if ($ContentWritten) {
          $SubSubDirectory = Join-Path $InputDirCurrent $SubdirectoryOrderFileLine
          if (Test-Path -Path $SubSubDirectory -PathType "Container") {
            $NewTocSubdirectories = $TocSubdirectories.Clone()
            $NewTocSubdirectories += $SubdirectoryOrderFileLine
            Copy-Tree -BaseDirectory $BaseDirectory -TocFileString ([ref]$SubTocContents) -TocSubdirectories $NewTocSubdirectories -AttachmentPaths $AttachmentPaths
          }
        }
      }
    }
  }
}

# Function to copy an Azure Devops wiki file to a DocFX file
function Copy-MarkdownFile {
  param (
    [string]$RelPath,
    [string]$RelDestination,
    [int]$Level,
    [System.Collections.Generic.List[string]]$AttachmentPaths
  )

  Write-Host "Processing page '$RelPath' to '$RelDestination'"

  $Path = Join-Path $InputDir $RelPath
  $Destination = Join-Path $OutputDir $RelDestination

  $ThreeDotsStarted = 0;
  $Silent = $false
  $ContentWritten = $false
  $DirCreated = $false
  foreach($MdLine in Get-Content -Path $Path) {
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

    # Find attachments
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
      $AttachmentPathParts = $AttachmentPath.Split('/') | ForEach-Object { [uri]::UnescapeDataString($_) }
      $AttachmentPath = [IO.Path]::Combine($AttachmentPathParts)
      $AttachmentPaths.Add($AttachmentPath)
    }

    # Make absolute links relative
    $RelativePathPrefix = "../" * $Level
    $MdLine = $MdLine.Replace("](/", "]($RelativePathPrefix")

    # Write to destination file
    if ($Silent -eq $false) {
      if (-not $DirCreated) {
        $DestDir = Split-Path $Destination
        if (-not (Test-Path $DestDir)) {
          New-Item -Path $DestDir -ItemType "directory"
        }
        $DirCreated = $true
      }

      Add-Content -Path $Destination -Value $MdLine
      $ContentWritten = $true
    }
    elseif ($ThreeDotsStarted -lt 1) {
      $Silent = $false
    }
  }

  return $ContentWritten
}

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

$AttachmentPaths = [System.Collections.Generic.List[string]]::new()

$HomepageMdFilePath = "$($OrderFileLines[0])$MarkdownExtension"
Copy-MarkdownFile -RelPath $HomepageMdFilePath -RelDestination $DocFxHomepageFilename -Level 0 -AttachmentPaths $AttachmentPaths | Out-Null

# Create TOC file and for the rest of the files in the .order file and copy files to the right directory
$TocContents = ""
foreach($OrderFileLine in ($OrderFileLines | Select-Object -Skip 1))
{
  $TocContents += "- name: $OrderFileLine`n"
  $TocContents += "  href: $OrderFileLine/`n"
  $TocContents += "  topicHref: $OrderFileLine/`n"

  # Toc file in subdirectory
  $SubTocContents = ""

  # Markdown file in subdirectory
  $FirstLevelPageMdFilePath = "$OrderFileLine$MarkdownExtension"
  $FirstLevelPageDestPath = Join-Path $OrderFileLine $DocFxSectionIntroductionFilename
  $FirstLevelPageWritten = Copy-MarkdownFile -RelPath $FirstLevelPageMdFilePath -RelDestination $FirstLevelPageDestPath -Level 1 -AttachmentPaths $AttachmentPaths

  # If a directory exists with the name, then it has subitems
  if ($FirstLevelPageWritten) {
    $SubDirectory = Join-Path $InputDir $OrderFileLine
    if (Test-Path -Path $SubDirectory -PathType "Container") {
      Copy-Tree -BaseDirectory $OrderFileLine -TocFileString ([ref]$SubTocContents) -AttachmentPaths $AttachmentPaths
    }
    
    # Write section TOC file
    if ($SubTocContents) {
      Set-Content -Path (Join-Path (Join-Path $OutputDir $OrderFileLine) $DocFxTocFilename) -Value $SubTocContents
    }
  }
}
# TOC file schrijven
Set-Content -Path (Join-Path $OutputDir $DocFxTocFilename) -Value $TocContents

# If attachments found...
$AttachmentPathsCount = $AttachmentPaths.Count
if ($AttachmentPathsCount -gt 0) {
  # Create attachments directory in destination
  $AttachmentsDestDir = Join-Path $OutputDir $AttachmentsDirName
  New-Item -Path $AttachmentsDestDir -ItemType "directory" | Out-Null

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
        New-Item -Path $AttachmentPathDirFull -ItemType "directory" | Out-Null
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

Exit 0
