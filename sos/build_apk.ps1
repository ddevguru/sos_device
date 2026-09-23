$cleanPath = ($env:PATH.Split(';') | Where-Object { $_ -notmatch 'MinGW' }) -join ';'
$env:PATH = $cleanPath
Write-Host "Filtered PATH (removed MinGW). Building release APK..."
flutter build apk --release
