@echo off
for %%f in (goose-*.ps1) do (
    if not "%%f"=="run-all.bat" (
        start "" powershell -ExecutionPolicy Bypass -File "%%f"
    )
)
