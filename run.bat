@echo off
echo Checking for Love2D installation...

if exist "C:\Program Files\LOVE\love.exe" (
    echo Love2D found! Starting the game...
    "C:\Program Files\LOVE\love.exe" .
) else (
    echo Love2D not found! Please install it from https://love2d.org/
    echo After installation, run this batch file again.
    pause
) 