@echo off
rem Modo compatibilidade (OpenGL): mais leve, para placas antigas ou com problema de video
start "" "%~dp0JunkContructionSimulator.exe" --rendering-method gl_compatibility --rendering-driver opengl3
