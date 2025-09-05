@echo off
powershell -ExecutionPolicy Bypass -File "%~dp0Export-BitbucketPR.ps1" %*
pause

