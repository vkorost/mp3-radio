# mp3-radio

Automated DJ radio station pipeline powered by Claude Code. Drop a folder of MP3s,
get back a shuffled playlist where every song is introduced by a comedian-style DJ.

## What It Does

1. **Parses** audio filenames (and ID3 tags as fallback) to extract artist and title
2. **Assigns** one of 7 comedian voices to each track (deterministic via seed)
3. **Generates** a short, funny DJ intro in that comedian's style using Claude
4. **Renders** each intro to speech via ElevenLabs TTS (3 distinct DJ voices)
5. **Assembles** a shuffled playlist folder — DJ intro, then song, repeat — ready
   to copy to any music player

## Prerequisites

- **Claude Code CLI** — installed and authenticated ([docs](https://docs.anthropic.com/en/docs/claude-code))
- **Python 3.8+** with packages: `mutagen`, `requests`
- **ElevenLabs account** — Starter plan or above ($5/mo, 30K characters)
- **Comedian style skills** — install all 7 from [claude-standup-skills](https://github.com/vkorost/claude-standup-skills)

### Install Python dependencies

```bash
pip install -r requirements.txt
```

### Install comedian skills

Follow the instructions at https://github.com/vkorost/claude-standup-skills to
install all 7 style skills into your Claude Code environment.

## Usage

```
produce_radio_playlist.cmd <ELEVENLABS_API_KEY> <AUDIO_FOLDER> <PLAYLIST_FOLDER>
```

**Example:**

```
produce_radio_playlist.cmd sk-abc123def456 "C:\Music\HardRock" "D:\Playlist"
```

### Parameters

| Parameter | Description |
|---|---|
| `ELEVENLABS_API_KEY` | Your ElevenLabs API key from [elevenlabs.io](https://elevenlabs.io) |
| `AUDIO_FOLDER` | Path to a folder containing `.mp3` and/or `.m4a` files |
| `PLAYLIST_FOLDER` | Path to output folder for the final shuffled playlist |

### Output

All output goes in the playlist folder you specify:

```
PLAYLIST_FOLDER/
  001_DJ-Intro - Saxon - Ride like the wind.mp3   <- DJ intro (moved from TTS)
  002_Saxon - Ride like the wind.mp3              <- song (copied from source)
  003_DJ-Intro - Lana Lane - Kashmir.mp3
  004_Lana Lane - Kashmir.mp3
  ...
  text-data/                                      <- working files (see below)
```

### The `text-data/` folder

Inside your playlist folder, the pipeline creates a `text-data/` subdirectory
that holds all intermediate working files:

| File | Purpose |
|---|---|
| `dj_intros.json` | Sidecar JSON — parsed track data and generated intro texts. This is the source of truth for the pipeline. |
| `dj_intros_review.md` | Human-readable review of all intros with flags and metadata. |
| `tts/` | Staging area for rendered TTS MP3 files. Emptied after playlist assembly (files are moved, not copied). |

**This folder is safe to delete after the pipeline completes.** The final playlist
files are self-contained in the parent folder. However, keeping `text-data/`
enables two things:

- **Incremental runs** — if you add new songs and re-run, existing intros and TTS
  renders are reused from `text-data/`, saving time and ElevenLabs quota.
- **Review** — you can inspect `dj_intros_review.md` to see all generated intros,
  flags, and metadata before distributing the playlist.

To force a full regeneration from scratch, delete the `text-data/` folder before
running.

## Security Note: Autonomous Mode

The `produce_radio_playlist.cmd` script invokes Claude Code with `--dangerously-skip-permissions`.
This means Claude will execute commands (writing files, running Python scripts,
calling the ElevenLabs API) without asking for permission at each step.

**What this means:**

- Claude can read/write files in the project directory and the output folder
- Claude can execute Python scripts it writes
- Claude can make HTTP calls to the ElevenLabs API using your key
- No human approval is required for individual actions

**If you prefer manual approval**, edit `produce_radio_playlist.cmd` and remove the
`--dangerously-skip-permissions` flag. Claude will then prompt you before each
action, which is safer but requires you to stay at the keyboard.

**If you prefer interactive mode** (recommended for first run), run Claude Code
directly in the project directory instead of using `produce_radio_playlist.cmd`:

```bash
cd mp3-radio
claude
```

Then paste the prompt manually and approve each step.

## How It Works

The pipeline is defined in `dj-radio-station.md` (the assignment spec). Claude Code
reads this file, writes Python scripts to handle parsing and API calls, uses its
comedian style skills to write intros, and assembles the final playlist. The
`CLAUDE.md` file provides project-level instructions that Claude loads automatically.

### Comedian Voices

Each track is assigned one of 7 comedian styles, mapped to 3 ElevenLabs TTS voices:

| TTS Voice | Style | Comedians |
|---|---|---|
| David Hertal | Warm, conversational radio DJ | Louis CK, Colin Quinn |
| Rachel M | Measured British presenter | Ricky Gervais, Bill Maher |
| Tyler Cruz | Energetic, punchy DJ | George Carlin, Bill Hicks, Doug Stanhope |

### Hard Rules for Intros

The intros follow strict rules to stay accurate and timeless:

- No fabricated facts (dates, chart positions, anecdotes)
- No assumed band personnel (many bands changed lineups)
- No listener-specific references (nationality, culture)
- No forward-looking statements (intros must work decades from now)
- Self-contained — no references to other tracks or playlist context
- Flag uncertain tracks rather than guess

See `dj-radio-station.md` for the complete rule set.

## Configuration

Edit the YAML block in `dj-radio-station.md` to customize:

- `AUDIO_EXTENSIONS` — add `.flac`, `.aac`, `.ogg` if needed
- `RANDOM_SEED` / `SHUFFLE_SEED` — change for different voice assignments or shuffle order
- `INTRO_WORDS_MIN` / `INTRO_WORDS_MAX` — adjust intro length (default 25-70 words)
- `ELEVENLABS_VOICE_SETTINGS` — tweak TTS voice parameters
- `ELEVENLABS_VOICES` — swap in different ElevenLabs voices

## License

MIT
