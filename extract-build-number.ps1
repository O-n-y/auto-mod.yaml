param(
    [string]$AssemblyPath = "Assembly-CSharp.dll",
    [string]$ModInfoPath = "mod_info.yaml"
)

try {
    if (-not (Test-Path $AssemblyPath)) {
        $commonPaths = @(
            "Assembly-CSharp.dll",
            "Managed/Assembly-CSharp.dll", 
            "../Managed/Assembly-CSharp.dll",
            "Data/Managed/Assembly-CSharp.dll",
            "../../Managed/Assembly-CSharp.dll"
        )
        
        foreach ($path in $commonPaths) {
            if (Test-Path $path) {
                $AssemblyPath = $path
                break
            }
        }
        
        if (-not (Test-Path $AssemblyPath)) {
            throw "Assembly-CSharp.dll not found"
        }
    }
    
    if (-not (Test-Path $ModInfoPath)) {
        throw "mod_info.yaml not found at: $ModInfoPath"
    }
    
    Write-Host "Loading assembly from: $AssemblyPath"
    
    $assembly = [System.Reflection.Assembly]::LoadFrom((Resolve-Path $AssemblyPath))
    $kleiVersionType = $assembly.GetType("KleiVersion")
    
    if ($null -eq $kleiVersionType) {
        throw "KleiVersion class not found in assembly"
    }
    
    $changeListField = $kleiVersionType.GetField("ChangeList", [System.Reflection.BindingFlags]::Public -bor [System.Reflection.BindingFlags]::Static)
    
    if ($null -eq $changeListField) {
        throw "ChangeList field not found in KleiVersion class"
    }
    
    $buildNumber = $changeListField.GetValue($null)
    
    $lines = Get-Content $ModInfoPath
    $updated = $false
    $oldBuild = "unknown"
    
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match "^(\s*minimumSupportedBuild\s*:\s*)(\d+)\s*$") {
            $oldBuild = $Matches[2]
            $lines[$i] = $Matches[1] + $buildNumber
            $updated = $true
            Write-Host "Updated minimumSupportedBuild from $oldBuild to $buildNumber"
            break
        }
    }
    
    if (-not $updated) {
        throw "minimumSupportedBuild field not found in mod_info.yaml"
    }
    
    $lines | Set-Content $ModInfoPath
    Write-Host "Successfully updated $ModInfoPath with minimumSupportedBuild: $buildNumber"
    exit 0
}
catch {
    Write-Error $_.Exception.Message
    exit 1
}