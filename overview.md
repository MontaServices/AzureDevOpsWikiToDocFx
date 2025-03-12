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

# Template

Use `DocfxGlobalMetadata` task input to set metadata to customizing the appearance of pages. See: https://dotnet.github.io/docfx/docs/template.html?tabs=modern#template-metadata.

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
    DocfxGlobalMetadata: '{ "_appName": "MyDocs", "_appTitle": "MyDocs", "_enableSearch": true, "_disableNextArticle": true }'

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