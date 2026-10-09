# Rage Quit Rumble

The scoreboard for our yearly gaming tournament. Friends log in with Discord, log matches, and get standings, records and per-player stats. League of Legends is set up; more games can be added from the Games tab.

It is a static site (the `docs/` folder, served by GitHub Pages) backed by a free Supabase project, which stores the data and handles Discord login.

## One-time setup (about 10 minutes)

### 1. Create the database
1. Sign up at https://supabase.com and create a **New project** (the free plan is enough). Note the database password somewhere safe.
2. Open **SQL Editor → New query**, paste the whole of `supabase/setup.sql`, and press **Run**.

### 2. Create the Discord app
1. Go to https://discord.com/developers/applications and press **New Application**. Name it "Rage Quit Rumble".
2. Open **OAuth2**. Copy the **Client ID**, then press **Reset Secret** and copy the **Client Secret**.
3. Under **Redirects**, add `https://snfnpmnpdykskzlajwyy.supabase.co/auth/v1/callback` (your project URL from Supabase, plus `/auth/v1/callback`) and save.

### 3. Turn on Discord login in Supabase
1. In Supabase, open **Authentication → Sign In / Providers → Discord**.
2. Switch it on, paste the Client ID and Client Secret, and save.
3. Open **Authentication → URL Configuration**. Set **Site URL** to `https://durrannus.github.io/Rage-quit-rumble/` and add the same address under **Redirect URLs**.

### 4. Connect the site to the database
1. In Supabase, open **Project Settings → API**. Copy the **Project URL** and the **anon public** key.
2. Put them in `docs/config.js`. The anon key is designed to be public; the rules in `setup.sql` protect the data.

### 5. Publish the site
In this GitHub repo, open **Settings → Pages**, choose **Deploy from a branch**, pick `main` and `/docs`, and save. After a minute the site is live at `https://durrannus.github.io/Rage-quit-rumble/`.

### 6. Log in first
The **first person to log in becomes the organiser**, so log in yourself before sharing the link. Then send the link to your friends. When they log in and join the roster, approve them on the **Players** tab; approved players can log and delete matches. Anyone can view the scores without logging in.

## How scoring works
- Win 3 points, loss 0, and +1 for the match MVP (highest KDA).
- Each year is its own tournament; there is also an "All time" view.
- The Rage Quit Award goes to the most deaths in a single game.
- Scoring and stats are set per game and can be changed in the `games` table.
