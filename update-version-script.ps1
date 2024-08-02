param(
    [string]$assemblyInfoPath,
    [string]$modInfoPath
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

    $content = Get-Content $filePath -Raw
    $versionPattern = '(?<=Assembly(?:File)?Version\(")(\d+\.\d+\.\d+\.)(\d+)(?="\))'
    $titlePattern = '(?<=AssemblyTitle\(")([^"]+)(?="\))'
    
    $versionMatches = [regex]::Matches($content, $versionPattern)
    $titleMatch = [regex]::Match($content, $titlePattern)
    
    if ($versionMatches.Count -eq 2 -and $titleMatch.Success) {
        $updatedContent = $content
        $newVersion = ""

        foreach ($match in $versionMatches) {
            $currentVersion = $match.Groups[0].Value
            $majorMinorPatch = $match.Groups[1].Value
            $build = [int]$match.Groups[2].Value
            
            $newBuild = $build + 1
            $newVersion = "${majorMinorPatch}${newBuild}"
            
            $updatedContent = $updatedContent -replace [regex]::Escape($currentVersion), $newVersion
        }
        
        Set-Content -Path $filePath -Value $updatedContent
        Write-Output "AssemblyInfo.cs: Version updated to $newVersion"
        return @{
            Version = $newVersion
            Title = $titleMatch.Groups[1].Value
        }
    }
    else {
        Write-Error "Expected two version patterns and a title in AssemblyInfo.cs but found $($versionMatches.Count) version(s) and $(if($titleMatch.Success){'a'}else{'no'}) title."
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
    if (Test-Path $filePath) {
        $lines = Get-Content $filePath
	$updatedLines = foreach ($line in $lines) {
   	if ($line -match '^version: ') {
        	"version: $newVersion"
	} else {
		$line
		}
	}
$updatedContent = $updatedLines -join "`n"
Set-Content -Path $filePath -Value $updatedContent
Write-Output "mod_info.yaml: Version updated to $newVersion"
    } else {
        $content = @"
supportedContent: ALL
minimumSupportedBuild: 619020
APIVersion: 2
version: $newVersion
"@
        New-Item -Path $filePath -ItemType File -Force | Out-Null
        Set-Content -Path $filePath -Value $content
        Write-Output "mod_info.yaml: Created with version $newVersion"
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

# Validate input parameters
if ([string]::IsNullOrWhiteSpace($assemblyInfoPath) -or [string]::IsNullOrWhiteSpace($modInfoPath)) {
    Write-Error "One or more required paths are empty or null. Please provide valid paths for all parameters."
    exit 1
}

# Update AssemblyInfo.cs and get new version and title
$result = Update-AssemblyVersions -filePath $assemblyInfoPath

if ($result -ne $false) {
    # Update mod_info.yaml with new version
    Update-ModInfoVersion -filePath $modInfoPath -newVersion $result.Version
    
    $modInfoDirectory = Split-Path -Path $modInfoPath -Parent

    # Update or create mod.yaml with staticID
    Update-ModYaml -directoryPath $modInfoDirectory -staticID $result.Title

    $modYamlPath = Join-Path -Path $modInfoDirectory -ChildPath "mod.yaml"

    # Verify mod.yaml exists
    if (Test-Path $modYamlPath) {
        Write-Output "mod.yaml successfully created/updated at $modYamlPath"
    } else {
        Write-Error "Failed to create mod.yaml at $modYamlPath"
        exit 1
    }
} else {
    exit 1
}
