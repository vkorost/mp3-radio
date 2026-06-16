# Assignment: DJ Radio Station — Intro Generation & Playlist Assembly

## Objective

Given a folder of audio files, parse artist and title for each, assign a randomly
selected comedian voice from a fixed pool of seven, generate a spoken-style DJ intro
for each track, render the intros to audio via ElevenLabs TTS, and assemble a
shuffled playlist folder where each song is preceded by its DJ intro. The output
folder is ready to copy to any music player.

## Configuration

```yaml
INPUT_FOLDER: ""                                 # passed at runtime by produce_radio_playlist.cmd
AUDIO_EXTENSIONS: [".mp3", ".m4a"]               # add .flac/.aac/.ogg if needed
PLAYLIST_FOLDER: ""                              # passed at runtime by produce_radio_playlist.cmd
WORKING_DIR: "<PLAYLIST_FOLDER>/text-data"            # all intermediate files go here
OUTPUT_REVIEW_MD: "<WORKING_DIR>/dj_intros_review.md"
OUTPUT_SIDECAR_JSON: "<WORKING_DIR>/dj_intros.json"
TTS_DIR: "<WORKING_DIR>/tts"                     # temporary; TTS files are moved to playlist

COMEDIAN_POOL:                                   # seven comedian style skills
  - style-ricky-gervais
  - style-louis-ck
  - style-george-carlin
  - style-doug-stanhope
  - style-colin-quinn
  - style-bill-maher
  - style-bill-hicks

RANDOM_SEED: 42                                  # fixed seed = reproducible voice assignment
SHUFFLE_SEED: 42                                 # fixed seed = reproducible playlist order
INTRO_WORDS_MIN: 25
INTRO_WORDS_MAX: 70
MAX_CONSECUTIVE_SAME_VOICE: 2                    # avoid long runs of one comedian

ENABLE_METADATA_LOOKUP: false                    # if true, pull verified facts from MusicBrainz only
# --- ElevenLabs TTS ---
ELEVENLABS_API_KEY: ""                           # read from environment variable ELEVENLABS_API_KEY
ELEVENLABS_MODEL: "eleven_multilingual_v2"
ELEVENLABS_VOICE_SETTINGS:
  stability: 0.4
  similarity_boost: 0.75
  style: 0.35

# Three ElevenLabs voices, each covering 2-3 comedian styles.
# Grouping matches comedian delivery energy to voice character.
ELEVENLABS_VOICES:
  david_hertal:                                  # David Hertal - Radio DJ (warm, conversational)
    voice_id: "FmJ4FDkdrYIKzBTruTkV"
    comedians:
      - style-louis-ck                           # conversational, everyman storytelling
      - style-colin-quinn                        # dry, conversational NYC wit
  rachel_m:                                      # Rachel M - Pro British Radio Presenter (measured, wry)
    voice_id: "aD6riP1btT197c6dACmy"
    comedians:
      - style-ricky-gervais                      # British, self-aware, irreverent
      - style-bill-maher                         # smooth, sardonic, confident
  tyler_cruz:                                    # Tyler Cruz - Cool Energetic DJ (punchy, intense)
    voice_id: "SA7eD52NRr8WAehitVt1"
    comedians:
      - style-george-carlin                      # rapid-fire wordplay, anti-establishment
      - style-bill-hicks                         # passionate, philosophical, intense
      - style-doug-stanhope                      # raw, blunt, confrontational
```

## Hard rules

1. **No fabricated specifics.** Assert only well-established facts (who the band is,
   that a track is a cover of a known original, broad era). Do not invent dates,
   chart positions, sales figures, personnel, studios, or anecdotes.

2. **No assumptions about band personnel.** Do not name a vocalist, guitarist, or
   specific lineup member unless the filename explicitly states the name. Many rock
   bands have had multiple singers and lineups across decades. Guessing wrong is
   worse than not mentioning. Refer to the band, not its members, unless the member
   is the credited artist (solo act or explicit collaboration).

3. **No listener-specific references.** Do not reference the listener's nationality,
   location, culture, language, or personal context. Do not use phrases like "in my
   country," "where I come from," or any culturally-specific framing. The intros
   must work for any listener anywhere.

4. **Self-contained intros.** Each DJ intro must be completely self-sufficient.
   It may reference only the artist, title, and album of the track it introduces.
   Never reference other tracks in the collection, other versions of the same song,
   how many tracks by the same artist appear in the set, or any playlist-level
   context. The intro must make perfect sense even if the track is moved to a
   different folder or playlist. Never write "you just heard," "coming up next,"
   "last track," "we close with," "also in the set," "one of several from this
   artist," or any language that assumes a fixed sequence or a specific collection.

5. **No file silently dropped.** Every file matching `AUDIO_EXTENSIONS` appears
   exactly once in all outputs. Unparseable files are listed as `UNIDENTIFIED`,
   not skipped.

6. **Non-Latin tracks are out of scope.** Files whose name or tags are non-Latin
   or arrive as mojibake (runs of `?`) are flagged `UNIDENTIFIED` with reason
   `non-latin`, and no intro is generated.

7. **Intro ends at the handoff to the song.** No outro, no sign-off, no closing line.
   The DJ talks, introduces the track, and the music starts.

8. **If `ENABLE_METADATA_LOOKUP` is true**, the only sanctioned source of specific
   facts is MusicBrainz (release year, album, original writer). Use nothing else.
   If you do not know anything about a song beyond the name, do a quick lookup to
   understand what the song is about and what a DJ might say. If you cannot verify
   a fact, write tonal or contextual banter instead of guessing.

9. **Flag if uncertain.** If you do not recognize a song with confidence — the
   title does not match any known track, the artist is obscure, or you suspect the
   filename may be mislabeled — set `needs_review = true` with reason
   `unverified_song` and write a safe, generic intro that avoids any specific
   claims about the song. Do not fabricate context for a song you cannot identify.
   List these in the "Needs Renaming" section so the user can verify or provide
   additional information.

10. **No forward-looking or time-sensitive statements.** Never imply an artist is
    currently alive, active, touring, or "still going." No present-tense claims
    about what an artist *is* or *does* today. No predictions ("will never stop,"
    "will keep rocking"). Intros must be timeless — equally valid whether listened
    to today or fifty years from now. Many of these musicians are already dead;
    many more will be. Talk about the *music* and the *legacy*, not the artist's
    current status. Use past tense for biographical facts; present tense only for
    the song or the music itself (which is immortal on the recording).

## Phase 0: Setup

- Verify `INPUT_FOLDER` exists and is readable.
- Confirm a tag reader is available (mutagen preferred; ffprobe acceptable).
- Confirm all seven skills in `COMEDIAN_POOL` are installed locally. If any are
  missing, halt and print the missing names. Do not substitute.
- Read `ELEVENLABS_API_KEY` from the environment variable.
- Confirm all `ELEVENLABS_VOICES` voice IDs are accessible (test with a short API call).

## Phase 1: Enumerate

- List files whose extension (case-insensitive) is in `AUDIO_EXTENSIONS`.
- Exclude `files.txt`, hidden files, and zero-byte files.
- Sort alphabetically for deterministic processing.
- Record total count.

## Phase 2: Parse artist and title (filename first, tag fallback)

Apply in order; stop at the first that resolves. Record `source` as `filename`,
`tag`, or `none`, and a `confidence` of `high`, `moderate`, or `low`.

1. **Strip extension.** Remove the file extension. Strip zero-width Unicode
   characters (U+200B, U+200C, U+200D, U+FEFF).

2. **Cover detection:** if the name contains `Cover by` or an `@handle`, set
   `is_cover = true`. The leading token before the first ` - ` is the
   `original_artist`; the name(s) after `Cover by` are the `performer`; the middle
   segment is the `title`. Set `artist = original_artist`.

3. **Reversed form `TITLE (ARTIST)`:** if there is no ` - ` separator and the name
   matches `Something (Name)` where the parenthetical is not a technical tag
   (live, remix, acoustic, edit, version, remaster, demo, radio edit) or a year,
   swap so artist = parenthetical, title = stem.

4. **Doubled artist:** split on ` - `; if the first segment repeats later
   (e.g. `Rainbow - Rainbow - Title`, `Styx - Styx - Title`, `Vixen - Title -
   Vixen`), drop the duplicate and resolve to `Artist - Title`.

5. **Suffix segment:** if there are 3+ ` - ` segments after dedup and the trailing
   segment is a film, album, or medley tag, treat segment 1 as artist and default
   to the last segment as title; set `needs_review` so a human confirms which
   segment is the real title.

6. **Standard `Artist - Title`.** Split on ` - `. If the separator lacks a leading
   space (e.g. `Artist- Title`), also try splitting on `- `.

7. **No separator or empty artist** (e.g. `Final.Countdown.mp3`,
   `Various Artists - ...`): read embedded tags via mutagen (easy mode). If tags
   yield artist and title, use them with `source = tag`. `Various Artists` as
   artist is not usable; fall to tags.

8. **Still unresolved,** or non-Latin/mojibake, or pure novelty with no parseable
   artist (e.g. `If AUDIOSLAVE wrote Take My Breath Away`): set `UNIDENTIFIED`,
   `source = none`, `needs_review = true`, with a short reason. Do not guess.

**Cleanup:** replace underscores with spaces in parsed artist and title. Collapse
multiple spaces. Trim whitespace.

For each file record: `filename`, `artist`, `title`, `is_cover`, `original_artist`,
`performer`, `source`, `confidence`, `needs_review`, `review_reason`.

## Phase 3: Collection index

- Group by normalized title (strip non-alphanumeric, lowercase). Mark any title
  appearing in more than one file with a `duplicate_count`. Expose this to Phase 5.
- Group by artist. Identify artists that recur across the folder.

## Phase 4: Assign voice

- Seed RNG with `RANDOM_SEED`.
- For each file in processing order, pick one voice from `COMEDIAN_POOL`, subject to
  `MAX_CONSECUTIVE_SAME_VOICE`.
- Record the assigned voice per file. Same seed reproduces the same assignment.

## Phase 5: Generate intro text

For each resolved (non-UNIDENTIFIED) file:

- Load the style skill named in that file's assigned voice and write the intro in
  that comedian's voice.
- Length within `INTRO_WORDS_MIN`..`INTRO_WORDS_MAX` words. Spoken cadence; this
  text will be rendered to speech.
- Introduce artist and title. Obey all Hard Rules.
- If `is_cover`: frame it explicitly as a cover. Name the original artist only when
  high-confidence. When `performer` is known, credit the performer.
- If `duplicate_count > 1`: the voice may reference that multiple versions of this
  song exist, but do not assume playback order or playlist context.
- Do not write an intro for `UNIDENTIFIED` files; emit a placeholder line stating
  the file must be renamed.

### Caching

If `OUTPUT_SIDECAR_JSON` exists from a prior run, load it. For any track that
already has a non-empty `intro_text`, skip regeneration and keep the existing text.
Only generate intros for new tracks or tracks with empty `intro_text`.

## Phase 6: Text output

### Review Markdown (`OUTPUT_REVIEW_MD`)

Header block with run config and summary counts: total files, parsed from filename,
parsed from tag, covers, duplicate-title groups, UNIDENTIFIED.

Then one block per file, in processing order:

```
### <filename>
Artist: <artist | UNIDENTIFIED>   Title: <title | ->
Voice: <comedian>
Flags: <cover, duplicate(N), needs_review:reason, or none>

<intro text>
```

After the blocks, a "Needs Renaming" section listing every UNIDENTIFIED and
`needs_review` file with its reason, so they can be fixed in one pass.

### Sidecar JSON (`OUTPUT_SIDECAR_JSON`)

Array of objects, one per file:

```json
{
  "filename": "",
  "artist": "",
  "title": "",
  "is_cover": false,
  "original_artist": "",
  "performer": "",
  "voice": "",
  "source": "filename|tag|none",
  "confidence": "high|moderate|low",
  "needs_review": false,
  "review_reason": "",
  "duplicate_count": 1,
  "intro_text": ""
}
```

The sidecar is the input to Phase 7.

## Phase 7: Render TTS

For each entry with a non-empty `intro_text`:

- Look up the comedian-to-voice mapping in `ELEVENLABS_VOICES` to get the
  ElevenLabs voice ID.
- Call the ElevenLabs text-to-speech API:
  - Endpoint: `POST https://api.elevenlabs.io/v1/text-to-speech/{voice_id}`
  - Headers: `xi-api-key`, `Content-Type: application/json`, `Accept: audio/mpeg`
  - Body: `text`, `model_id`, `voice_settings` (from config)
- Save the result as an MP3 file in `TTS_DIR` (temporary staging).
- On HTTP 429 (rate limit), wait and retry up to 2 times with exponential backoff.
- Log success/failure for each file.
- Report total characters consumed (for quota tracking).
- **Caching:** If a TTS MP3 already exists in `TTS_DIR` for a given track and the
  `intro_text` has not changed since the last render, skip re-rendering.
- TTS files are staged here temporarily; Phase 8 will move them into the playlist.

UNIDENTIFIED files produce no TTS output.

## Phase 8: Build playlist

- Seed RNG with `SHUFFLE_SEED`.
- Shuffle all entries into random playback order.
- Create `PLAYLIST_FOLDER` (clean out any existing files).
- Number files sequentially with 3-digit zero-padded prefixes (001, 002, ...).
- For each entry in shuffled order:
  - If it has a DJ intro: move (not copy) the TTS MP3 from `TTS_DIR` to
    `PLAYLIST_FOLDER` as `NNN_DJ-Intro - Artist - Title.mp3`
  - Immediately after: copy the original audio file as `NNN_originalfilename.ext`
  - Increment the counter by 2 (or by 1 if no intro).
- Sanitize filenames: remove characters illegal on FAT32/exFAT (`< > : " / \ | ? *`).
- The result is a folder that plays in correct order on any device that sorts by
  filename.

### Naming convention

```
001_DJ-Intro - Saxon - Ride like the wind.mp3        <- DJ intro (TTS)
002_Saxon - Ride like the wind.mp3                   <- song (copied from source)
003_DJ-Intro - Lana Lane - Kashmir.mp3               <- DJ intro (TTS)
004_Lana Lane - Kashmir.mp3                          <- song (copied from source)
...
```

DJ-Intro files use the parsed artist and title (cleaned). Song files retain
the original filename with the sequence number prepended.

## Acceptance criteria

- Every `.mp3` and `.m4a` file in `INPUT_FOLDER` appears exactly once in the sidecar
  JSON, the review Markdown, and the playlist folder.
- No file dropped silently; all UNIDENTIFIED and needs_review files are listed in
  the renaming section.
- Each generated intro is within the word bounds and contains no fabricated facts,
  no assumed personnel, no listener-specific references, no order-dependent
  language, and no time-sensitive statements.
- Voice assignment is reproducible under a fixed seed and recorded per file.
- Playlist order is reproducible under a fixed shuffle seed.
- TTS rendering produces one MP3 per intro with zero silent failures.
- The playlist folder contains exactly `(N_intros + N_songs)` files, correctly
  numbered so that each DJ intro immediately precedes its song.
