# Check arg
if ($args.count -lt 2){
    echo "Usage: run.ps1 MAINFILE.dart PLATFORM"
    echo "Default main file is: app.dart"
    echo "Platforms: android, ios, windows, macos, linux, web"
    return
}
if (Test-Path -Path "./platforms/modules-$($args[1])" -PathType Container){
    echo "Using platform $($args[1])"
    echo "Copying platform files over to 'modules' dir..."
}
else{
    echo "No such platform at 'platforms/modules-$($args[1])'"
}

# Copy files
$files = Get-ChildItem -Path "./platforms/modules-$($args[1])/*" -File -recurse

foreach ($file in $files) {
    Write-Host "Found file: $($file.FullName)"

    # Make lowdash after file name
    $absPath = $($file.FullName)
    $newPath = Resolve-Path -Path $absPath -Relative
    $newPath = $newPath -replace "\.dart", "_.dart"
    $newPath = $newPath -replace "\\platforms", ""
    $newPath = $newPath -replace "-$($args[1])", ""
    echo "Copying to: $newPath"

    # Make target folder path
    $destFolder = Split-Path -Path $newPath -Parent
    
    if (-not (Test-Path -Path $destFolder -PathType Container)) {
        New-Item -Path $destFolder -ItemType Directory -Force | Out-Null
    }

    # Copy
    Copy-Item -Path $absPath -Destination $newPath -Force
}

# Watcher to overwrite files (truncate+write and not del+createNew)
# those files in platforms/modules-* directories
# ChatGPT, edited
$platform = $args[1]

$job = Start-Job -argumentList $platform -ScriptBlock {
    $w = [IO.FileSystemWatcher]::new((Get-Location).Path)
    $w.EnableRaisingEvents = $true
    $w.IncludeSubdirectories = $true
    $logFile = Join-Path (Get-Location).Path "watcher.log"
    $plat = $args[0]

    Register-ObjectEvent $w Changed -SourceIdentifier FileChanged -Action {
        $changedFile = $Event.SourceEventArgs.FullPath
        if ($changedFile -eq $logFile){ return }

        if ($changedFile -match '\.(dart|js|html|css)$') {
            if ($changedFile -match "platforms\\modules-"){
                clear-content -path "watcher.log"
                add-content -path "watcher.log" -value $changedFile

                $content = Get-Content -Path $changedFile -Raw
                $targetFile = $changedFile -replace "platforms\\modules-$plat","modules"
                $targetFile = $targetFile -replace "\.dart$","_.dart"
                add-content -path "watcher.log" -value "Copy to: $targetFile"

                clear-content $targetFile
                add-content -path $targetFile -value $content
            }
        }        
    }

    while ($true) { Wait-Event | Out-Null }
}
 
# Run Dart
echo ""

# May break webview:
# dart run --observe app.dart 

# Webview ok
echo "================================================================================"
echo "In order to pull new code from Dawio: Do not edit existing code files in Dawio."
echo "Add new files only, eg. clone app-sample.dart to app.dart to run."
echo "================================================================================"
try {
dart run --enable-vm-service $args[0]
# dart $args[0]
    }
finally {
    Write-Host "Stopping watcher..."
    Stop-Job $job -ErrorAction SilentlyContinue
    Remove-Job $job -ErrorAction SilentlyContinue
    Write-Host "Watcher stopped."
}
