' Desktop Goose UI Launcher (Silent)
Set WshShell = CreateObject("WScript.Shell")
currentPath = WshShell.CurrentDirectory

Set objShell = CreateObject("Shell.Application")
objShell.Open currentPath & "\goose-ui.bat"
