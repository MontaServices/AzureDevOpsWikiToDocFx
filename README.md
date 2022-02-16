An Azure DevOps pipeline task to turn your [Azure DevOps wiki](https://docs.microsoft.com/en-us/azure/devops/project/wiki/wiki-create-repo) into an [DocFX website](https://dotnet.github.io/docfx/).

This allows to to create a public documentation website with the nice wiki editing tools of Azure DevOps. 

# Supports

- Links between pages
- Images
- Mermaid diagrams

# Does not support

Didn't find anything yet.

# Template

To use a certain docfx template, place the template files in a directory named ".docfx_template" in your wiki repository.

# Hiding content

To hide content, surround it with "::: private" and ":::". E.g.:

```
Content publicly visible in the DocFX website.

::: private
This will not be visible in the DocFX website.
::: 

This will be visible again. 
```
