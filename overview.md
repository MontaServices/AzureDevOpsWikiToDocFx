An Azure DevOps pipeline task to turn your [Azure DevOps wiki](https://docs.microsoft.com/en-us/azure/devops/project/wiki/wiki-create-repo) into an [DocFX website](https://dotnet.github.io/docfx/).

This allows to to create a public documentation website with the nice wiki editing tools of Azure DevOps. 

# Supports

- Links between pages
- Images
- Mermaid diagrams
- Running the website in a subdirectory: all the links are made relative
- Copies only referenced attachments

# Does not support

- Nothing that I currently know of.

# Hiding content

To hide content, surround it with `::: private` and `:::` (on their own line). E.g.:

```
Content publicly visible in the DocFX website.

::: private
This will not be visible in the DocFX website.
::: 

This will be visible again. 
```

If you put `::: private` at the start of the page and do not close it, the whole file will be ignored. 

# Usage

You can use this task in build and release.

## Build 

With a azure-pipelines.yml build file below, an artifact with the website files will be created. 
This you can release to a webserver.

```
trigger:
- main

pool: 
  vmImage: 'windows-latest'

steps:
- task: AzureDevOpsWikiToDocFx@1
  inputs:
    SourceFolder: '$(System.SourcesDirectory)'
    TargetFolder: '$(System.ArtifactStagingDirectory)/mydocs'

- task: CmdLine@2
  displayName: Install DocFX
  inputs:
    script: 'dotnet tool update -g do

- task: CmdLine@2
  displayName: DocFX build
  inputs:
    script: 'docfx $(Build.ArtifactStagingDirectory)/mydocs/docfx.json'

- task: PublishPipelineArtifact@1
  inputs:
    targetPath: '$(System.ArtifactStagingDirectory)/docfx/_site'
    publishLocation: 'pipeline'
```

## Release

Works quite the same as in a build pipeline.

# Configure DocFX (e.g. template)

This task generates a DocFX config as follows:

```
{
  "`$schema": "https://raw.githubusercontent.com/dotnet/docfx/main/schemas/docfx.schema.json",
  "build": {
    "content": [
      {
        "files": [
          "**/*.{md,yml}"
        ],
        "exclude": [
          "_site/**"
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
    "output": "_site",
    "template": [
      "default",
      "modern"
    ]
  }
}
```

You can modify this config in your pipeline with PowerShell, e.g. to change the template as described here: https://dotnet.github.io/docfx/docs/template.html.

This example adds metadata, a resource directory and a template.

```
$DocFxJsonPath = "$(Build.ArtifactStagingDirectory)/MyDocs/docfx.json"
$DocFxJson = Get-Content $DocFxJsonPath -Raw 

$GlobalMetadataJson = '{ "_appName": "MyDocs", "_appTitle": "MyDocs", "_enableSearch": true, "_disableNextArticle": true, "_lang": "nl", "_appLogoPath": "files/logo.svg", "_appFaviconPath": "files/favicon.ico" }'

$DocFx = $DocFxJson | ConvertFrom-Json
$DocFx.build | Add-Member -Name "globalMetadata" -Value (ConvertFrom-Json $GlobalMetadataJson) -MemberType NoteProperty -Force

$DocFx.build.resource[0].files += "files/**"
$DocFx.build.template += "MontaTemplate"

$DocFxJson = ConvertTo-Json $DocFx -Depth 99

Write-Output "Writing new config:"
Write-Output $DocFxJson
```
