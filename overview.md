An Azure DevOps pipeline task to turn your [Azure DevOps wiki](https://docs.microsoft.com/en-us/azure/devops/project/wiki/wiki-create-repo) into an [DocFX website](https://dotnet.github.io/docfx/).

This allows to to create a public documentation website with the nice wiki editing tools of Azure DevOps. 

# Supports

- Links between pages
- Images
- Mermaid diagrams
- Running the website in a subdirectory: all the links are made relative

# Does not support

- Nothing that I currently know of.

# Template

This project contains a modified version of the default DocFX template to get everything to work. 

To use your own docfx template, copy the template files in this repository to adirectory named ".docfx_template" in your wiki repository. Then modify the template to your needs. 

# Targeting differerent audiences

A page or part a page can be made visible for certain audiences only.

In the task configuration you can specify one or more 'target audiences'.

To include a page only for Customers for example, specify "Customers" as target audience and put this line on top of the file.

```
[[Audience: Customers]]
```

To hide part of a page use:

```
[[Audience: Customers

This line is only included when Customers is specified as target audience.

]]
```

Including content for multiple audiences is also possible. E.g.: `[[Audience: Customers,Staff]]`

If a target audience is specified in the task configuration, and a page has no audience specified on top, the file will not be included.

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