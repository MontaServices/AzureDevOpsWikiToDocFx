# Usage

Please see [overview.md](overview.md).

# Test

```
.AzureDevOpsWikiToDocFx\AzureDevOpsWikiToDocFxLaunch.ps1 -InputDir "{path to directory with checked out Azure DevOps wiki files}" -OutputDir "{directory to create with DocFX project}" -TemplateDir "{path to template dir, you can also point to the default template in AzureDevOpsWikiToDocFx\docfx_template}"
```

# Publish 

* Raise version in vss-extension.json and AzureDevOpsWikiToDocFx/task.json
* Run `tfx extension create --manifest-globs vss-extension.json`
* Publish file at Visual Studio Marketplace
