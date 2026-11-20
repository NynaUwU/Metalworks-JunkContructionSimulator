@echo off
rem Modo compatibilidade (OpenGL): mais leve e simples, para placas antigas ou com problema de video
start "" "%~dp0Sucata.exe" --rendering-method gl_compatibility --rendering-driver opengl3
