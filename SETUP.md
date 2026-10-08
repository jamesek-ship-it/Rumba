# Rumbo Español: accounts setup

Accounts and cloud-saved progress use Supabase. Until you fill in the two values below, the app works
exactly as before and keeps progress on the device only (the "Entrar" button stays hidden).

1. **Project.** Create a Supabase project. A separate project from Dadchelor is cleanest, because
   people who sign up share one user list per project.
2. **Schema.** Open the SQL editor and run `supabase/schema.sql`. It creates the `rumbo_progress`
   table with row-level security (each person can only touch their own row), a
   `delete_my_account()` function for the "Delete my account" button, and the
   `rumbo_group_members` table behind the optional group leaderboard. If you already ran the
   earlier version, run just the "Group leaderboard" block at the bottom.
3. **Keys.** In Settings > API copy the project URL and the anon (publishable) key into the top of
   `config.js`
   (`supabaseUrl` and `supabaseAnonKey`). Only that file ever holds your keys, so replacing `index.html`
   for an update never erases them. The anon key is meant to be public. Never put the
   service_role key anywhere in this repo.
4. **Auth URLs.** In Authentication > URL Configuration set the Site URL to the deployed address
   (for example https://rumbo.yourdomain.com) and add the same address to Redirect URLs. Confirmation
   and password-reset emails send people back there.
5. **Email.** In Authentication > Providers > Email decide whether to require email confirmation.
   The app handles both. For real use, set up custom SMTP, because Supabase's built-in sender is
   heavily rate limited.
6. **Deploy.** Commit, push, bump `CACHE` in `sw.js`, and let Cloudflare Pages deploy.

`vendor/supabase.js` is supabase-js 2.117.2, copied in so the app and sign-in screen load offline.

## Sharing the app with the boys

- Open the app, pick the country, set the trip date, then copy the link under **Invita a los muchachos**.
  The link looks like `https://your-site/?c=ec&d=2026-11-14`. Anyone who opens it lands on that country
  with the countdown already set. The first time they open it, they still pick a level.
- The group leaderboard is optional and needs accounts. Tap **Add a group leaderboard**, give yourself a
  name, and the link now carries a group code (`&g=XXXXXXXX`). Friends who sign in and join with the link
  see each other's phrases learned and days practiced this week. Nothing else is shared.
- Anyone with the link can join the group, so share it only with the people you mean to.

## Recursos tab: trip info and the currency converter

- **Trip info** (flights, where you are staying, schedule, contacts) lives in `trip.js`. Edit only that file;
  app updates never overwrite it. Leave `sections` empty and the card stays hidden. There is an example
  in the comments at the top of the file.
- **Exchange rates** live in `rates.json` and are refreshed every Monday by a GitHub Action
  (`.github/workflows/rates.yml`, which runs `scripts/update_rates.py`). It uses ExchangeRate-API's free
  open endpoint, needs no key, and refuses to save a rate that looks wrong. To refresh by hand, open the
  repo's **Actions** tab, pick **Update exchange rates**, and click **Run workflow**.
- Ecuador uses US dollars, so its Recursos tab says there is nothing to convert.

## Conversation mode (free chat with a coach)

Needs accounts (above), an Anthropic API key, and one Supabase Edge Function.

1. **API key.** At console.anthropic.com, add a few dollars of credit under Billing, set a monthly spend
   limit, and create an API key. (This is separate from a Claude subscription.)
2. **Database.** In the Supabase SQL editor, run `supabase/chat.sql` (the same block that is at the
   bottom of `supabase/schema.sql`).
3. **Function.** Supabase > Edge Functions > Deploy a new function > Via Editor. Name it exactly
   `rumbo-chat`, paste in `supabase/functions/rumbo-chat/index.ts`, and deploy.
4. **Secret.** Supabase > Edge Functions > Secrets, add `ANTHROPIC_API_KEY` with your key.
   Optional: `CHAT_MODEL` to change the model (default `claude-haiku-4-5-20251001`).

The function checks that the caller is signed in, allows 40 messages per person per day (Eastern time,
change `DAILY_LIMIT` in the function to adjust), and keeps no transcripts.
