@echo off
setlocal
cd /d "%~dp0"

set "GODOT=%~dp0Godot_v4.7.2-stable_win64.exe"
if exist "%GODOT%" goto run

set "GODOT=C:\Users\ThinkPad\AppData\Local\Temp\opencode\godot\Godot_v4.7.2-stable_win64.exe"
if exist "%GODOT%" goto run

where godot.exe >nul 2>nul
if not errorlevel 1 (
    start "" godot.exe --path "%~dp0."
    exit /b 0
)

echo No se encontro Godot 4.7.
echo Abre project.godot con el editor de Godot o coloca Godot_v4.7.2-stable_win64.exe junto a este archivo.
pause
exit /b 1

:run
start "" "%GODOT%" --path "%~dp0."
