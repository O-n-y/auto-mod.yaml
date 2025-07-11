param(
    [string]$assemblyInfoPath,
    [string]$modInfoPath,
    [string]$gameAssemblyPath = "Assembly-CSharp.dll",
    [string]$extractBuildScriptPath = (Join-Path -Path (Split-Path -Parent $MyInvocation.MyCommand.Path) -ChildPath "extract-build-number.ps1")
)

function Update-AssemblyVersions {
    param([string]$filePath)

    if ([string]::IsNullOrWhiteSpace($filePath)) {
        Write-Error "AssemblyInfo path is empty or null."
        return $false
    }

    if (-not (Test-Path $filePath)) {
        Write-Error "AssemblyInfo file not found at path: $filePath"
        return $false
    }

    try {
        $backupPath = "$filePath.backup"
        Copy-Item $filePath $backupPath -Force
        
        $content = Get-Content $filePath -Raw -Encoding UTF8
        
        if ([string]::IsNullOrWhiteSpace($content)) {
            Write-Error "AssemblyInfo file is empty or could not be read"
            return $false
        }

        $versionPattern = '(?<=Assembly(?:File)?Version\(")(\d+\.\d+\.\d+\.)(\d+)(?="\))'
        $titlePattern = '(?<=AssemblyTitle\(")([^"]+)(?="\))'
        
        $versionMatches = [regex]::Matches($content, $versionPattern)
        $titleMatch = [regex]::Match($content, $titlePattern)
        
        if ($versionMatches.Count -eq 2 -and $titleMatch.Success) {
            $updatedContent = $content
            $newVersion = ""

            $sortedMatches = $versionMatches | Sort-Object { $_.Index } -Descending
            
            foreach ($match in $sortedMatches) {
                $currentVersion = $match.Groups[0].Value
                $majorMinorPatch = $match.Groups[1].Value
                $build = [int]$match.Groups[2].Value
                
                $newBuild = $build + 1
                $newVersion = "${majorMinorPatch}${newBuild}"
                
                $startIndex = $match.Index
                $length = $match.Length
                $updatedContent = $updatedContent.Substring(0, $startIndex) + $newVersion + $updatedContent.Substring($startIndex + $length)
            }
            
            if ([string]::IsNullOrWhiteSpace($updatedContent)) {
                Write-Error "Updated content is empty. Restoring from backup."
                Copy-Item $backupPath $filePath -Force
                return $false
            }
            
            Set-Content -Path $filePath -Value $updatedContent -Encoding UTF8 -NoNewline
            
            $verifyContent = Get-Content $filePath -Raw -Encoding UTF8
            if ([string]::IsNullOrWhiteSpace($verifyContent)) {
                Write-Error "File became empty after writing. Restoring from backup."
                Copy-Item $backupPath $filePath -Force
                return $false
            }
            
            Remove-Item $backupPath -Force -ErrorAction SilentlyContinue
            
            Write-Output "AssemblyInfo.cs: Version updated to $newVersion"
            return @{
                Version = $newVersion
                Title = $titleMatch.Groups[1].Value
            }
        }
        else {
            Write-Error "Expected two version patterns and a title in AssemblyInfo.cs but found $($versionMatches.Count) version(s) and $(if($titleMatch.Success){'a'}else{'no'}) title."
            Copy-Item $backupPath $filePath -Force
            return $false
        }
    }
    catch {
        Write-Error "Error updating AssemblyInfo: $($_.Exception.Message)"
        if (Test-Path "$filePath.backup") {
            Copy-Item "$filePath.backup" $filePath -Force
        }
        return $false
    }
}

function Update-ModInfoVersion {
    param(
        [string]$filePath,
        [string]$newVersion
    )
    
    if ([string]::IsNullOrWhiteSpace($filePath)) {
        Write-Error "mod_info.yaml path is empty or null."
        return
    }

    try {
        if (Test-Path $filePath) {
            $lines = Get-Content $filePath
            $versionUpdated = $false
            
            for ($i = 0; $i -lt $lines.Count; $i++) {
                if ($lines[$i] -match "^(\s*version\s*:\s*)(.+)\s*$") {
                    $oldVersion = $Matches[2]
                    $lines[$i] = $Matches[1] + $newVersion
                    $versionUpdated = $true
                    Write-Output "mod_info.yaml: Updated version from $oldVersion to $newVersion"
                    break
                }
            }
            
            if (-not $versionUpdated) {
                $lines += "version: $newVersion"
                Write-Output "mod_info.yaml: Added version $newVersion"
            }
            
            $lines | Set-Content $filePath
        }
        else {
            $content = @"
supportedContent: ALL
minimumSupportedBuild: 661174
APIVersion: 2
version: $newVersion
"@
            New-Item -Path $filePath -ItemType File -Force | Out-Null
            Set-Content -Path $filePath -Value $content
            Write-Output "mod_info.yaml: Created with version $newVersion"
        }
    }
    catch {
        Write-Error "Error updating mod_info.yaml version: $($_.Exception.Message)"
    }
}

function Update-ModYaml {
    param(
        [string]$directoryPath,
        [string]$staticID
    )
    $filePath = Join-Path -Path $directoryPath -ChildPath "mod.yaml"

    if ([string]::IsNullOrWhiteSpace($filePath)) {
        Write-Error "mod.yaml path is empty or null."
        return
    }

    try {
        if (-not (Test-Path $filePath)) {
            $content = "staticID: $staticID"
            New-Item -Path $filePath -ItemType File -Force | Out-Null
            Set-Content -Path $filePath -Value $content -ErrorAction Stop
            Write-Output "mod.yaml: Created with staticID $staticID at $filePath"
        } else {
            $content = Get-Content $filePath -Raw
            if ($content -notmatch 'staticID:') {
                $content = "staticID: $staticID`n$content"
                Set-Content -Path $filePath -Value $content -ErrorAction Stop
                Write-Output "mod.yaml: Added staticID $staticID"
            } else {
                Write-Output "mod.yaml: Already contains staticID, no changes made"
            }
        }
    }
    catch {
        Write-Error "Error creating or updating mod.yaml: $_"
    }
}

function Invoke-ExtractBuildNumber {
    param(
        [string]$scriptPath,
        [string]$assemblyPath,
        [string]$modInfoPath
    )
    
    try {
        if (-not (Test-Path $scriptPath)) {
            Write-Warning "Extract build script not found at: $scriptPath"
            Write-Warning "Skipping build number update. Please ensure extract-build-number.ps1 is in the same directory."
            return
        }
        
        Write-Output "`n--- Build Number Update ---"
        Write-Output "Calling extract-build-number.ps1..."
        Write-Output "Assembly path: $assemblyPath"
        Write-Output "Mod info path: $modInfoPath"
        
        $scriptArgs = @()
        if (-not [string]::IsNullOrWhiteSpace($assemblyPath) -and $assemblyPath -ne "Assembly-CSharp.dll") {
            $scriptArgs += "-AssemblyPath"
            $scriptArgs += "`"$assemblyPath`""
        }
        $scriptArgs += "-ModInfoPath"
        $scriptArgs += "`"$modInfoPath`""
        
        Write-Output "Script arguments: $($scriptArgs -join ' ')"
        
        $output = & powershell.exe -ExecutionPolicy Bypass -File $scriptPath @scriptArgs 2>&1
        
        foreach ($line in $output) {
            if ($line -is [System.Management.Automation.ErrorRecord]) {
                Write-Warning "Extract script error: $($line.Exception.Message)"
            } else {
                Write-Output "Extract script: $line"
            }
        }
        
        if ($LASTEXITCODE -eq 0) {
            Write-Output "Build number extraction completed successfully"
        } else {
            Write-Warning "Build number extraction script returned error code: $LASTEXITCODE"
        }
    }
    catch {
        Write-Warning "Error calling extract build number script: $($_.Exception.Message)"
        Write-Warning "Continuing without build number update..."
    }
}

if ([string]::IsNullOrWhiteSpace($assemblyInfoPath) -or [string]::IsNullOrWhiteSpace($modInfoPath)) {
    Write-Error "One or more required paths are empty or null. Please provide valid paths for all parameters."
    exit 1
}

Write-Output "=== Starting Version Update ==="
Write-Output "Assembly Info: $assemblyInfoPath"
Write-Output "Mod Info: $modInfoPath"
Write-Output "Game Assembly: $gameAssemblyPath"
Write-Output "Extract Script: $extractBuildScriptPath"

$result = Update-AssemblyVersions -filePath $assemblyInfoPath

if ($result -ne $false) {
    Update-ModInfoVersion -filePath $modInfoPath -newVersion $result.Version
    
    Invoke-ExtractBuildNumber -scriptPath $extractBuildScriptPath -assemblyPath $gameAssemblyPath -modInfoPath $modInfoPath
    
    $modInfoDirectory = Split-Path -Path $modInfoPath -Parent

    Update-ModYaml -directoryPath $modInfoDirectory -staticID $result.Title

    $modYamlPath = Join-Path -Path $modInfoDirectory -ChildPath "mod.yaml"

    if (Test-Path $modYamlPath) {
        Write-Output "mod.yaml successfully created/updated at $modYamlPath"
    } else {
        Write-Error "Failed to create mod.yaml at $modYamlPath"
        exit 1
    }
    
    Write-Output "`n=== Update Summary ==="
    Write-Output "Mod version: $($result.Version)"
    Write-Output "Mod title: $($result.Title)"
    
    Write-Output "`n--- Final mod_info.yaml content ---"
    Get-Content $modInfoPath | ForEach-Object { Write-Output $_ }
} else {
    exit 1
}