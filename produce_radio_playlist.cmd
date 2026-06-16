@echo off
setlocal enabledelayedexpansion

:: DJ Radio Station - Automated Pipeline Runner
:: Usage: produce_radio_playlist.cmd <ELEVENLABS_API_KEY> <AUDIO_FOLDER> <PLAYLIST_FOLDER>

if "%~1"=="" goto :usage
if "%~2"=="" goto :usage
if "%~3"=="" goto :usage

:: Validate audio folder exists
if not exist "%~2" (
    echo ERROR: Audio folder not found: %~2
    exit /b 1
)

:: Create output and working directories if needed
if not exist "%~3" mkdir "%~3"
if not exist "%~3\past" mkdir "%~3\past"

:: Set environment variables for Python scripts to read
set "ELEVENLABS_API_KEY=%~1"

:: Change to project directory so Claude reads CLAUDE.md
cd /d "%~dp0"

:: Invoke Claude Code with full autonomous permissions
claude --dangerously-skip-permissions -p "Execute the DJ Radio Station pipeline. Read dj-radio-station.md for the full specification. Audio source folder: \"%~2\". Playlist output folder: \"%~3\". Working directory for intermediate files: \"%~3\past\". The ElevenLabs API key is available as environment variable ELEVENLABS_API_KEY. If the working directory already contains dj_intros.json, preserve existing intros and only generate intros for new or missing tracks. Skip TTS rendering for intro MP3s that already exist in the working directory."

goto :eof

:usage
echo.
echo   DJ Radio Station - Automated Pipeline Runner
echo.
echo   Usage: produce_radio_playlist.cmd ^<ELEVENLABS_API_KEY^> ^<AUDIO_FOLDER^> ^<PLAYLIST_FOLDER^>
echo.
echo     ELEVENLABS_API_KEY  Your ElevenLabs API key (from elevenlabs.io)
echo     AUDIO_FOLDER        Path to folder containing MP3/M4A audio files
echo     PLAYLIST_FOLDER     Path to output folder for the shuffled playlist
echo.
echo   Example:
echo     produce_radio_playlist.cmd sk-abc123def456 "C:\Music\HardRock" "D:\Playlist"
echo.
echo   Output structure:
echo     PLAYLIST_FOLDER\001_DJ-Intro - Artist - Title.mp3
echo     PLAYLIST_FOLDER\002_Artist - Title.mp3
echo     PLAYLIST_FOLDER\past\dj_intros.json         (working files)
echo     PLAYLIST_FOLDER\past\dj_intros_review.md
echo.
echo   Prerequisites:
echo     - Claude Code CLI (claude) installed and authenticated
echo     - Python 3.8+ with mutagen and requests packages
echo     - Comedian style skills installed (see README.md)
echo.
exit /b 1
