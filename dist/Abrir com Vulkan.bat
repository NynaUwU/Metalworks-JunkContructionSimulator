@echo off
rem Abre o jogo usando Vulkan (use se o modo normal/Direct3D 12 der problema)
start "" "%~dp0JunkContructionSimulator.exe" --rendering-driver vulkan
