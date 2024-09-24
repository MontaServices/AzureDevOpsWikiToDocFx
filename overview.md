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

This project contains a modified version of the default DocFX template to get everything to work. 

To use your own docfx template, copy the template files in this repository to a directory named ".docfx_template" in your wiki repository. Then modify the template to your needs. 

# Hiding content

To hide content, surround it with "::: private" and ":::" (on their own line). E.g.:

```
Content publicly visible in the DocFX website.

::: private
This will not be visible in the DocFX website.
::: 

This will be visible again. 
```

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
    SourceFolder: '$(System.DefaultWorkingDirectory)'
    TargetFolder: '$(System.DefaultWorkingDirectory)/docfx'
- task: DocFxTask@0
  inputs:
    solution: 'docfx/docfx.json'
- task: PublishBuildArtifacts@1
  inputs:
    PathtoPublish: '$(System.DefaultWorkingDirectory)/docfx/_site'
    ArtifactName: 'drop'
    publishLocation: 'Container'
```

## Release

Works quite the same as in a build pipeline.