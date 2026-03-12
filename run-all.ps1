Get-ChildItem -Filter "goose-*.ps1" | Where-Object { $_.Name -ne "run-all.ps1" } | ForEach-Object {
    Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -File `"$($_.FullName)`""
}
