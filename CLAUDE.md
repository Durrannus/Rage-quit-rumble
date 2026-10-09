# Rage Quit Rumble

A yearly gaming tournament between friends, run by Darren (the organiser). The site tracks scores, roasts players and plays back the best moments. The first game is League of Legends **ARAM Mayhem**.

- Live site: https://durrannus.github.io/Rage-quit-rumble/
- Repo: https://github.com/Durrannus/Rage-quit-rumble (branch `main`)

## How it's built

- **No build step.** The site is one static page, `docs/index.html` (vanilla JS, inline CSS), served by GitHub Pages from `/docs` on `main`. A push to `main` deploys it.
- **Supabase** is the backend: Postgres with row-level security, Realtime, Storage and Discord OAuth login. `docs/config.js` holds the project URL and the anon key, and both are public by design. Supabase loads from a CDN script tag.
- **Accounts.** The first person to log in became the organiser (`admins` table, checked with `is_admin()`). Others join or claim a player name, and the organiser approves them (`is_approved()`). Anyone can read. Approved players can log and delete matches. Only the organiser can add games, add voice clips, change settings and set the Discord webhook. Player names are Discord names.
- **Replay import.** League `.rofl` files are parsed in the browser with no Riot API key. The parser finds the last `{"gameLength` JSON block and reads `statsJson`. Each entry saves `riot` (the in-game name, used to auto-match players next time), `fun` stats (time dead, pings, tower damage, rerolls and so on, which drive the roasts), augments and multikills. Augment names come from CommunityDragon `cherry-augments.json` and champion art from Data Dragon, both fetched at runtime.
- **Discord posts.** On save, the client writes summary text into `matches.announce`. A database trigger (`pg_net`) posts it to the webhook stored in the admin-only `secrets` table, so the webhook never reaches the browser.
- **Voice clips.** Call recordings are analysed in the browser (loudness spikes compared with the speaker's normal level). Only the 10-second WAV clips the user keeps are uploaded, to the `clips` storage bucket, with one row per clip in `public.clips`.

- **Video montage.** This is organiser only and runs entirely in the browser. Highlight clips from Outplayed or Medal are sorted into plays and throws by file name (`guessClip`). Scenes are drawn on a canvas, and audio (music, which falls back to the `synthBeat` loop, game audio and voice clips) is mixed in Web Audio. `MediaRecorder` records it, preferring MP4/H.264 and falling back to WebM. The result is downloaded, never uploaded.

### Code map (`docs/index.html`)
- `render()` rebuilds the page from the state object `S`: `header()+body()+ceremony()+statCard()+clipMaker()`.
- Clicks are handled by delegation on `data-act="..."`. Inputs use `data-bind="path.in.S"`, and `data-rerender` re-renders on change.
- `loadAll()` loads games, players and matches, then the optional tables (comments, app_settings, clips). Each optional table has an `...Off` fallback, so the site still works if a migration hasn't been run.
- Main areas: standings, match cards (scoreboard layout), awards ceremony slides, Hall of Shame, player page (achievements, rivalries), stats card pop-up with form meter, penalty jar, organiser settings (Games tab).

## Database migrations

The SQL files in `supabase/` are **run by hand** in Supabase › SQL Editor (paste the whole file, press Run). Each one is idempotent and safe to re-run.

1. `setup.sql`: base schema and RLS
2. `002_trash_talk.sql`: comments (superseded by 003)
3. `003_discord_and_settings.sql`: comments, `app_settings`, `secrets`, Discord trigger
4. `004_voice_clips.sql`: `clips` bucket and table

A new change gets a new numbered file. Don't edit a migration that has already been run. Tell Darren the exact file to run, and make the front end degrade gracefully until he has run it.

## Design and tone (Darren's preferences)

- **Clean, uncluttered, very clear, gamer vibe.** Darren gave full design control but pushes back on clutter. Hide extras behind "More" or an icon rather than adding them to cards.
- **Match the neon logo** (`docs/logo.jpg`): synthwave purple background, lime→cyan→magenta gradients, glow. The tokens live on `:root`: `--bg #0b0516`, `--accent #20f0e4`, `--accent2 #ff3fd2`, `--lime #c6ff2e`, `--flame #ff8a1f`. Headings use Bungee, and body/display text uses Chakra Petch.
- **Fun and funny, not dry stats.** It's between friends: roast awards, team quirks, Hall of Shame, penalty jar, achievements. Keep the jokes affectionate.
- Pop-ups (awards ceremony, stats card, clip maker) are framed windows, not full-screen.
- It must work on a phone (390px wide, no horizontal scroll).

## Conventions

- Keep everything in `docs/index.html` unless there's a strong reason not to. Match the existing terse style.
- Escape all user text with `esc()` before putting it into HTML.
- Never commit secrets. The Discord webhook URL, the Discord client secret and the database password must never appear in the repo or in chat. The webhook is pasted only into the site's Organiser settings.
- Test with Playwright, using a mocked `window.supabase` (served in place of `config.js`), on desktop and at 390px. Check for page errors.
- Update `README.md` when a setup step changes.
