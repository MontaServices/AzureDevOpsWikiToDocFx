# Usage

Please see [overview.md](overview.md).

# Develop

These instructions were used to setup this project: https://4bes.nl/2021/02/21/create-a-custom-azure-devops-powershell-task/.

# Test

```
.\AzureDevOpsWikiToDocFx\AzureDevOpsWikiToDocFxLaunch.ps1 -InputDir "{path to directory with checked out Azure DevOps wiki files}" -OutputDir "{directory to create with DocFX project}"
```

# Publish 

* Raise version in vss-extension.json and AzureDevOpsWikiToDocFx/task.json
* Run `tfx extension create --manifest-globs vss-extension.json`
* Publish file at Visual Studio Marketplace

To publish under a different name, change:
* in vss-extension.json: id, name
* in task.json: id, name, friendlyName