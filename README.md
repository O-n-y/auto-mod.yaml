# Yaml generator for Mods for Oxygen Not Included

## About

This is `PowerShell`(https://learn.microsoft.com/en-us/powershell/) script for generating and maintaining 2 files: `mod.yaml` and `mod_info.yaml`, required as part of mod making for the game Oxygen Not Included.

## Prepare



In your c# project create folder `Engine` and put inside `AssemblyInfo.cs` which should contain at least the version information and the tile:
```csharp
[assembly: AssemblyTitle("FavoriteBuildings")]
[assembly: AssemblyVersion("1.0.0.0")]
[assembly: AssemblyFileVersion("1.0.0.0")]
```
![image](https://github.com/user-attachments/assets/3c881f37-5c7b-4d85-9957-93a81d76189d)

In `Directory.props` or `.csproj` of your c# project add:

```xml

	<PropertyGroup>
		<LibDir>your_path</LibDir>
	</PropertyGroup>

	<Target Name="PreBuild" BeforeTargets="PreBuildEvent">
		<Exec Command="PowerShell -executionpolicy bypass -File &quot;$(LibDir)update-version-script.ps1&quot; -assemblyInfoPath &quot;$(ProjectDir)Engine\AssemblyInfo.cs&quot; -modInfoPath &quot;$(ProjectDir)mod_info.yaml&quot; -gameAssemblyPath &quot;$(GameManaged)Assembly-CSharp.dll&quot;" ContinueOnError="false" />
	</Target>
```
As you can see it is using the paths as the arguments, so if you want - you can easily edit it.

Change `LibDir` to the path of the directory where you located the `update-version-script.ps`.

Change `GameManaged` to the path of the directory where game Assembly-CSharp.dll is located.

## How it works

Each time the you will build the project, it will generate `mod.yaml` and `mod_info.yaml` files for you. 

![image](https://github.com/user-attachments/assets/2e105277-63f4-4e15-9d5a-5b38f7c3acc2)

It will also grab and **update** the actual build number from the game, which is storred in `KleiVersion` class in _Assembly-CSharp.dll_.

### mod.yaml
```yaml
supportedContent: ALL
minimumSupportedBuild: 619020 # will be auto updated from the Assembly-CSharp.dll
APIVersion: 2
version: 1.0.0.0  # will be changed to your project version from AssemblyInfo.cs
```
![image](https://github.com/user-attachments/assets/1b25c0f7-8289-4359-a43c-004a3beb1403)

### mod_info.yaml
```yaml
staticID: FavoriteBuildings # the name will be taken from your Project Name, stored in AssemblyTitle of the AssemblyInfo.cs
```
![image](https://github.com/user-attachments/assets/4d2ff598-807a-49d8-b03b-e4ae818fc131)


