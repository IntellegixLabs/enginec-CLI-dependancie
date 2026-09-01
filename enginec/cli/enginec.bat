@echo off
REM EngineC Compiler CLI Wrapper for Windows
REM This batch file wraps the enginec Node.js script for use on Windows
REM Place this file in your PATH (C:\EngineC\bin\ or similar)

node "%~dp0enginec.js" %*
