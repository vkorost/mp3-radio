# DJ Radio Station — Project Instructions

## What This Project Does
Generates comedian-style DJ intros for audio files, renders them to speech via
ElevenLabs TTS, and assembles a shuffled playlist where each song is preceded
by its DJ intro.

## How To Execute
Read `dj-radio-station.md` for the complete pipeline specification (Phases 0-8).
Execute all phases in order.

## Runtime Parameters
- **Audio source folder**: Provided in the prompt by `produce_radio_playlist.cmd`.
- **Playlist output folder**: Provided in the prompt by `produce_radio_playlist.cmd`. This is the
  final destination for the shuffled playlist — can be any path the user chooses.
- **Working directory**: `<PLAYLIST_FOLDER>/text-data/` — provided in the prompt.
  All intermediate files (JSON, review markdown, TTS renders, scripts) go here.
- **ElevenLabs API key**: Available as environment variable `ELEVENLABS_API_KEY`.
  Read it with `os.environ["ELEVENLABS_API_KEY"]` in Python scripts.

## Caching / Incremental Runs
- If the working directory already contains `dj_intros.json` from a prior run,
  load it. Preserve any entry that already has a non-empty `intro_text`. Only
  generate intros for tracks that are new or have an empty `intro_text`.
- If a TTS MP3 already exists in the working directory for a given track, skip
  re-rendering.
- This allows re-running the pipeline after adding new songs to the audio folder
  without regenerating everything.

## Comedian Style Skills
Intros are written using 7 comedian voice skills. These must be installed from:
https://github.com/vkorost/claude-standup-skills

The skills are:
- style-ricky-gervais
- style-louis-ck
- style-george-carlin
- style-doug-stanhope
- style-colin-quinn
- style-bill-maher
- style-bill-hicks

Use the Skill tool to invoke the assigned comedian style when generating each intro.

## Key Constraints
- All Hard Rules in `dj-radio-station.md` are mandatory. Pay special attention to:
  - No fabricated facts (Rule 1)
  - No assumed band personnel (Rule 2)
  - No forward-looking or time-sensitive statements (Rule 10) — intros must be
    timeless, valid 50 years from now
- Word count per intro: 25-70 words
- Every audio file must appear in the output — nothing silently dropped

## Python Dependencies
Scripts should use: `mutagen` (tag reading), `requests` (ElevenLabs API).
Both are expected to be pre-installed.
