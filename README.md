# mp3-radio

Turn a folder of your own MP3s into an offline radio station. An AI writes a short
DJ intro for every track in a rotating cast of comedian voices, renders each intro
to speech, and assembles a shuffled, ordered folder you can copy to any music
player. No streaming, no account on the device, no connection required at playback.

## Why This Exists

I swim whenever I get the chance. Underwater I listen to a bone conduction player.
That player has two constraints that shaped this whole project: it only plays MP3
files, and it has no screen. You press play and you do not know what comes next.

A plain shuffle of a music folder is functional but flat. What I actually wanted
was the thing radio gives you that a shuffle does not: a voice between the songs.
Someone telling you what is coming, with a bit of personality, before the music
starts. So I built that. Same idea as a radio station, except the station is your
own MP3 collection and the DJ is generated.

The result plays on the dumbest possible device. There is no app, no playlist
format, no metadata dependency at playback time. It is a folder of numbered MP3
files that sort in the right order: intro, song, intro, song. Any player that
plays files in filename order plays it correctly, including a screenless
bone conduction unit in a pool.

## What It Does

1. **Parses** audio filenames (with ID3 tags as fallback) to extract artist and title.
2. **Assigns** each track one of seven comedian voices, deterministically via a seed.
3. **Generates** a short DJ intro for each track in that comedian's written style,
   using Claude Code and a set of comedian style skills.
4. **Renders** each intro to speech via ElevenLabs TTS, mapping the seven written
   styles onto three distinct TTS voices.
5. **Assembles** a shuffled playlist folder: DJ intro, then the song it introduces,
   then the next intro, and so on. Files are zero-padded and numbered so any device
   that sorts by filename plays them in the intended order.

The pipeline is collection-aware where it helps (it can notice you have three
different versions of the same song) but every intro is written to stand on its own.

## How It Is Built (and Why)

This repo is not a packaged application. It is a Markdown assignment
(`dj-radio-station.md`) that Claude Code reads and executes. That is a deliberate
design choice, and most of the choices below follow from it. The assignment is the
product. The README is the story around it.

### Driven by a Markdown assignment, not a fixed program

The full pipeline spec lives in `dj-radio-station.md` as plain English, phase by
phase. Claude Code reads it, writes the Python it needs for parsing and API calls,
invokes the comedian skills to write the intros, and assembles the output.

Why: you customize this by editing English, not by reading and patching someone
else's code. Want different DJ personas, different intro length, a different naming
scheme, a different TTS backend? You change the spec and re-run. Claude Code adapts
the glue code to your environment. Packaging this as a rigid script would hide the
one thing that makes it adaptable.

### Filename first, tags as fallback

Parsing reads the filename first and only falls back to embedded ID3 tags when the
filename does not resolve.

Why: in a personal library the filename is usually cleaner and more accurate than
the tags, which are often blank, wrong, or stuffed with junk. Tags are the safety
net, not the primary source. Files that resolve from neither are flagged
`UNIDENTIFIED` and listed for renaming rather than guessed at.

### Deterministic seeds

Voice assignment and playlist shuffle are both seeded. The same input under the
same seed produces the same assignments and the same order every time.

Why: reproducibility. You can re-run after adding songs without the whole station
reshuffling into something unrecognizable, and you can share a configuration that
behaves the same on someone else's machine.

### Seven written styles, three TTS voices

There are seven comedian style skills in the pool. They map onto three ElevenLabs
voices, grouped by delivery energy (conversational, measured, punchy).

Why: the funny part lives in the text, written in each comedian's style. The TTS
voice supplies the delivery character. Three voices is enough variety for the ear
while keeping the TTS side simple and cheap. You are emulating a comedian's
writing, not cloning their actual voice, which keeps this clear of voice-likeness
problems.

### Hard rules that keep intros accurate and timeless

The spec forbids fabricated facts (dates, chart positions, personnel, anecdotes),
forbids naming band members who are not in the filename, forbids anything
listener-specific, and forbids forward-looking or present-tense claims about an
artist's current status.

Why: an intro that invents a fact is worse than one that does not. Many bands
changed lineups across decades; guessing the singer is a coin flip. Many of these
musicians are dead and more will be, so "still rocking" dates the recording
instantly. The intros talk about the music and the legacy, in past tense for
biography and present tense only for the song itself. They are meant to be as valid
fifty years from now as today. Every intro is also self-contained: because the
playlist is shuffled, no intro can say "coming up next" or "you just heard," since
it does not know its neighbors.

### Text and audio are separated, and both are cached

The pipeline writes all parsed data and generated intro text to a sidecar JSON
(`dj_intros.json`) before any TTS happens. The JSON is the source of truth. TTS
reads from it. Both intro generation and TTS rendering are cached: re-running after
adding songs reuses existing intros and existing audio.

Why: text generation is cheap, TTS costs money and quota. Separating them lets you
read and approve every intro before spending a character on ElevenLabs. Caching
means an incremental run only pays for the new tracks.

### Interleaved, zero-padded numbering

Output files are numbered `001`, `002`, `003` and so on, with each DJ intro
immediately preceding its song.

Why: the target is a player with no screen and no playlist support. The only
ordering it understands is filename sort. Zero-padded interleaving guarantees the
intro always plays right before its track on any such device.

## Prerequisites

- **Claude Code CLI**, installed and authenticated ([docs](https://docs.anthropic.com/en/docs/claude-code)).
- **Python 3.8+** with `mutagen` and `requests`.
- **ElevenLabs account** for TTS (Starter plan, about $5/mo, 30K characters). See
  "Using a different TTS backend" below if you want to avoid this.
- **Comedian style skills**, all seven, from
  [claude-standup-skills](https://github.com/vkorost/claude-standup-skills).

### Install Python dependencies

```bash
pip install -r requirements.txt
```

### Install comedian skills

Follow the instructions at https://github.com/vkorost/claude-standup-skills to
install all seven style skills into your Claude Code environment.

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
| `PLAYLIST_FOLDER` | Path to the output folder for the final shuffled playlist |

The launcher (`produce_radio_playlist.cmd`) is a Windows batch file. On macOS or
Linux, run Claude Code directly in the project directory (see "Running on
macOS/Linux" below) or write a short shell wrapper that does the same three things
the batch file does: set `ELEVENLABS_API_KEY`, create the output and `text-data`
folders, and invoke `claude` with the prompt.

### Output

All output goes in the playlist folder you specify:

```
PLAYLIST_FOLDER/
  001_DJ-Intro - Saxon - Ride like the wind.mp3   (DJ intro, moved from TTS staging)
  002_Saxon - Ride like the wind.mp3              (song, copied from source)
  ...
  015_DJ-Intro - The Cult - Fire Woman.mp3
  016_The Cult - Fire Woman.mp3
  ...
  168_DJ-Intro - Heart - Crazy On You.mp3
  169_Heart - Crazy On You.mp3
  ...
  text-data/                                      (working files, see below)
```

### The `text-data/` folder

Inside the playlist folder the pipeline creates a `text-data/` subdirectory for all
intermediate working files:

| File | Purpose |
|---|---|
| `dj_intros.json` | Sidecar JSON. Parsed track data and generated intro texts. The source of truth for the pipeline. |
| `dj_intros_review.md` | Human-readable review of all intros with flags and metadata. |
| `tts/` | Staging area for rendered TTS MP3s. Emptied after assembly (files are moved, not copied). |

This folder is safe to delete after the pipeline completes. The final playlist
files are self-contained in the parent folder. Keeping it enables two things:

- **Incremental runs**: add new songs, re-run, and existing intros and TTS renders
  are reused, saving time and ElevenLabs quota.
- **Review**: inspect `dj_intros_review.md` to read every generated intro, with
  flags, before you distribute the playlist.

To force a full regeneration, delete `text-data/` before running.

## Customizing It for Your Own Use

This is published as is. It works for me, but it is built around my setup: my
installed skills, my paths, my ElevenLabs key, my taste in DJs. I do not expect you
to run it exactly as I do. That is why the full assignment (`dj-radio-station.md`)
ships with the repo. It is the part you edit.

The general workflow for any change: open `dj-radio-station.md`, edit the relevant
phase or the YAML config block at the top in plain English, and re-run. For larger
changes, run Claude Code interactively in the project directory and describe the
change in conversation; it will modify the pipeline accordingly.

### Using a different TTS backend (cheaper or free)

ElevenLabs is only touched in **Phase 7** of the assignment. Everything before it
(parsing, voice assignment, intro text) and after it (shuffle, numbering, assembly)
is backend-agnostic. To swap it out, edit Phase 7 to call a different service, or
just tell Claude Code: "rewrite Phase 7 to render the intros with X instead of
ElevenLabs."

Options, from free to paid:

- **Piper**: free, local, offline, runs on your own machine. Good if you want zero
  recurring cost and no network dependency.
- **Coqui / XTTS, Kokoro**: free, local, higher quality, heavier to set up.
- **OS built-in TTS**: `say` on macOS, SAPI voices on Windows. Lowest quality, zero
  cost, already installed.
- **OpenAI, Azure, or Google Cloud TTS**: paid APIs, often cheaper per character
  than ElevenLabs, with their own voice rosters.

When you switch backends you will also remap the comedian-to-voice grouping
(`ELEVENLABS_VOICES` in the config) to whatever voices the new backend offers. The
three-voices-for-seven-styles structure is a convenience, not a requirement; use as
many or as few voices as your backend gives you.

### Changing the DJ personas

The seven comedians in `COMEDIAN_POOL` are just the style skills I installed. Swap
in any style skills you have or write your own. The pipeline does not care who the
personas are, only that the named skills exist locally.

### Other knobs in the config block

| Setting | Effect |
|---|---|
| `AUDIO_EXTENSIONS` | Add `.flac`, `.aac`, `.ogg`, etc. |
| `RANDOM_SEED` / `SHUFFLE_SEED` | Change for different voice assignments or shuffle order. |
| `INTRO_WORDS_MIN` / `INTRO_WORDS_MAX` | Intro length (default 25 to 70 words). |
| `MAX_CONSECUTIVE_SAME_VOICE` | Avoid long runs of one comedian. |
| `ENABLE_METADATA_LOOKUP` | If true, pull verified facts from MusicBrainz only. |
| `ELEVENLABS_VOICE_SETTINGS` | TTS voice parameters (stability, similarity, style). |

### Bigger changes

Anything in the spec is fair game: change the file naming scheme, change how the
review markdown is laid out, add a loudness pass, change the parsing rules for your
own filename conventions. Edit the English, or describe the change to Claude Code
and let it rewrite the relevant phase. The assignment is meant to be forked and
bent, not run untouched.

### Running on macOS/Linux

The `.cmd` launcher is Windows-only. Elsewhere, run interactively:

```bash
cd mp3-radio
export ELEVENLABS_API_KEY=sk-your-key
claude
```

Then tell Claude Code to execute the DJ Radio Station pipeline, giving it the audio
folder and the output folder. This is also the recommended mode for a first run,
since you can approve each step.

## Recommended Pre-Processing

For a station that actually sounds like a broadcast, normalize loudness and trim
dead air before running this pipeline, so you are never reaching to adjust the
volume between a quiet ballad and a loud one. Two companion tools handle that:

- **[mp3-norm](https://github.com/vkorost/mp3-norm)**: loudness-normalize a folder
  (EBU R128) so no track is louder or quieter than the next.
- **[mp3-trim](https://github.com/vkorost/mp3-trim)**: detect where the music ends
  and cut the trailing non-music (talk, applause, dead air) off the tail of each
  file. Music in the middle is preserved; only the tail is touched.

Run those over your library first, then feed the cleaned folder to mp3-radio for
the polished result.

## Security Note: Autonomous Mode

`produce_radio_playlist.cmd` invokes Claude Code with
`--dangerously-skip-permissions`. Claude will execute commands (writing files,
running Python, calling the ElevenLabs API) without asking for permission at each
step.

**What this means:**

- Claude can read and write files in the project directory and the output folder.
- Claude can execute Python scripts it writes.
- Claude can make HTTP calls to the ElevenLabs API using your key.
- No human approval is required for individual actions.

**For manual approval**, edit `produce_radio_playlist.cmd` and remove the
`--dangerously-skip-permissions` flag. Claude will then prompt before each action.

**For interactive mode** (recommended for a first run), run Claude Code directly in
the project directory instead of using the launcher, and approve each step:

```bash
cd mp3-radio
claude
```

## Reference

### Comedian voices and TTS mapping

Each track is assigned one of seven comedian styles, mapped to three ElevenLabs
voices grouped by delivery energy:

| TTS Voice | Style | Comedians |
|---|---|---|
| David Hertal | Warm, conversational radio DJ | Louis CK, Colin Quinn |
| Rachel M | Measured British presenter | Ricky Gervais, Bill Maher |
| Tyler Cruz | Energetic, punchy DJ | George Carlin, Bill Hicks, Doug Stanhope |

### Hard rules for intros

- No fabricated facts (dates, chart positions, anecdotes).
- No assumed band personnel (many bands changed lineups).
- No listener-specific references (nationality, culture, location).
- No forward-looking or time-sensitive statements (intros must work decades from now).
- Self-contained: no references to other tracks or playlist context.
- Flag uncertain tracks rather than guess.

See `dj-radio-station.md` for the complete rule set and the full phase-by-phase spec.

### Project files

| File | Role |
|---|---|
| `dj-radio-station.md` | The full pipeline assignment. The thing you edit and the thing Claude Code executes. |
| `CLAUDE.md` | Project-level instructions Claude Code loads automatically. |
| `produce_radio_playlist.cmd` | Windows launcher. Sets the API key, makes folders, invokes Claude Code. |
| `requirements.txt` | Python dependencies (`mutagen`, `requests`). |

## License

MIT
