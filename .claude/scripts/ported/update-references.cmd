@echo off
REM Convenience wrapper for Update-ReferenceRepos.ps1
REM
REM Usage: update-references.cmd [options]
REM
REM Options:
REM   --dry-run, -n     Show what would be done without making changes
REM   --force, -f       Re-clone repos even if they already exist
REM   --clean, -c       Rename directories to remove "(1)" suffixes
REM   --all             Run with -CleanNames (recommended for first run)
REM
REM Examples:
REM   update-references.cmd                 # Update existing repos
REM   update-references.cmd --dry-run       # Preview changes
REM   update-references.cmd --all           # Update and clean names
REM   update-references.cmd --clean         # Just clean directory names

setlocal enabledelayedexpansion

set SCRIPT_DIR=%~dp0
set PS_SCRIPT=%SCRIPT_DIR%Update-ReferenceRepos.ps1

set ARGS=

:parse_args
if "%1"=="" goto run_script
if "%1"=="--dry-run" set ARGS=!ARGS! -DryRun
if "%1"=="-n" set ARGS=!ARGS! -DryRun
if "%1"=="--force" set ARGS=!ARGS! -Force
if "%1"=="-f" set ARGS=!ARGS! -Force
if "%1"=="--clean" set ARGS=!ARGS! -CleanNames
if "%1"=="-c" set ARGS=!ARGS! -CleanNames
if "%1"=="--all" set ARGS=!ARGS! -CleanNames
shift
goto parse_args

:run_script
powershell -ExecutionPolicy Bypass -File "%PS_SCRIPT%" %ARGS%
