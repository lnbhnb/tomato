@echo off
echo ================================
echo   修仙桌宠 - 一键打包 EXE
echo ================================
echo.
echo 正在导出...
"%~dp0godot_engine\Godot_v4.4-stable_win64.exe" --headless --path "%~dp0." --export-release "Windows Desktop" "%~dp0build\修仙桌宠.exe"
echo.
echo 打包完成! 文件位于: build\修仙桌宠.exe
echo.
pause
