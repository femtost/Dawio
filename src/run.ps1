# Check arg
if ($args.count -lt 2){
    echo "Usage: run.ps1 VARIATION PLATFORM"
    echo "Example: run.ps1 sample windows --> runs app-sample.dart"
    echo "Example: run.ps1 test windows --> runs app-test.dart"
    echo "No variation: run.ps1 main windows --> runs app.dart"
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
$variation = $args[0]
$platform = $args[1]

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

# First frontend build
$vari = $variation

if ($vari -eq "main"){
    $curDir = get-location 
    cd frontend
    npx html-minifier index.html --collapse-whitespace --remove-comments --minify-css true `
        --minify-js true -o bundle.min.html

    npx esbuild index.css --bundle --minify --outfile=bundle.min.css 
    npx esbuild index.js --bundle --minify --sourcemap --outfile=bundle.min.js 
    cd $curDir 
}else{
    $curDir = get-location 
    cd frontend
    npx html-minifier index-$vari.html --collapse-whitespace --remove-comments --minify-css true `
        --minify-js true -o bundle.min.html

    npx esbuild index-$vari.css --bundle --minify --outfile=bundle.min.css 
    npx esbuild index-$vari.js --bundle --minify --sourcemap --outfile=bundle.min.js 
    cd $curDir 
}
echo "Frontend bundled"

# Watcher to overwrite files (truncate+write and not del+createNew)
# those files in platforms/modules-* directories
# ChatGPT, edited
$job = Start-Job -argumentList $variation,$platform -ScriptBlock {
    $w = [IO.FileSystemWatcher]::new((Get-Location).Path)
    $w.EnableRaisingEvents = $true
    $w.IncludeSubdirectories = $true
    $logFile = Join-Path (Get-Location).Path "watcher.log"
    $vari = $args[0]
    $plat = $args[1]

    Register-ObjectEvent $w Changed -SourceIdentifier FileChanged -Action {
        $changedFile = $Event.SourceEventArgs.FullPath
        if ($changedFile -eq $logFile){ return }

        # Overwrite current platform file
        if ($changedFile -match '\.(dart|js|html|css)$') {
            if ($changedFile -match "src\\platforms\\modules-"){
                # clear-content -path "watcher.log"
                (Get-Content "watcher.log" -Tail 100) | Set-Content "watcher.log"
                add-content -path "watcher.log" -value $changedFile

                $content = Get-Content -Path $changedFile -Raw
                $targetFile = $changedFile -replace "platforms\\modules-$plat","modules"
                $targetFile = $targetFile -replace "\.dart$","_.dart"
                add-content -path "watcher.log" -value "Copy to: $targetFile"

                clear-content $targetFile
                add-content -path $targetFile -value $content
            }
        }        
        # Rebuild frontend
        if ($changedFile -match '\.(js|html|css)$') {
            if ($changedFile -match "src\\frontend"){
                if ($vari -eq "main"){
                    (Get-Content "watcher.log" -Tail 100) | Set-Content "watcher.log"
                    add-content -path "watcher.log" -value $changedFile

                    $curDir = get-location 
                    cd frontend 
                    npx html-minifier index.html --collapse-whitespace --remove-comments `
                        --minify-css true `
                        --minify-js true -o bundle.min.html
                    npx esbuild index.css --bundle --minify --outfile=bundle.min.css 
                    npx esbuild index.js --bundle --minify --sourcemap --outfile=bundle.min.js 
                    cd $curDir 
                    add-content -path "watcher.log" "Bundled"
                }else{
                    (Get-Content "watcher.log" -Tail 100) | Set-Content "watcher.log"
                    add-content -path "watcher.log" -value $changedFile

                    $curDir = get-location 
                    cd frontend 
                    npx html-minifier index-$vari.html --collapse-whitespace --remove-comments `
                        --minify-css true `
                        --minify-js true -o bundle.min.html
                    npx esbuild index-$vari.css --bundle --minify --outfile=bundle.min.css 
                    npx esbuild index-$vari.js --bundle --minify --sourcemap --outfile=bundle.min.js 
                    cd $curDir 
                    add-content -path "watcher.log" "Bundled"
                }
            }
        }
    }
    while ($true) { Wait-Event | Out-Null }
} # Background job
 
# Webview ok
echo "================================================================================"
echo "In order to pull new code from Dawio: Do not edit existing code files in Dawio."
echo "Add new files only, eg. clone app-sample.dart to app.dart to run."
echo "================================================================================"
$app = ""

try {
    if ($variation -eq "main"){
        $app = "app.dart"
    }else{
        $app = "app-$variation.dart"
    }
    # For hot reload:
    # To disable: this line and HotReloader in app-?.dart
    dart run --enable-vm-service $app    
    # No hot reload:
    # dart $app    
}finally {
    Write-Host "Stopping watcher..."
    Stop-Job $job -ErrorAction SilentlyContinue
    Remove-Job $job -ErrorAction SilentlyContinue
    Write-Host "Watcher stopped."
}
# EOF