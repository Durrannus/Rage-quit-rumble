-- Rage Quit Rumble: Discord match posts, organiser settings, and trash talk.
-- Run once in Supabase > SQL Editor (paste the whole file, press Run).
-- Safe to run more than once. It also sets up trash talk, so you can skip 002.

-- Lets the database send web requests (used to post to Discord).
create extension if not exists pg_net;

-- ---------- trash talk (same as 002) ----------
create table if not exists public.comments (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references public.matches(id) on delete cascade,
  author uuid not null default auth.uid() references auth.users(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 280),
  created_at timestamptz not null default now()
);
alter table public.comments enable row level security;
drop policy if exists "read comments" on public.comments;
drop policy if exists "approved post comments" on public.comments;
drop policy if exists "delete own comments" on public.comments;
create policy "read comments" on public.comments for select using (true);
create policy "approved post comments" on public.comments for insert to authenticated
  with check (public.is_approved() and author = auth.uid());
create policy "delete own comments" on public.comments for delete to authenticated
  using (author = auth.uid() or public.is_admin());

-- ---------- settings everyone can read (penalty jar on/off, penalty list) ----------
create table if not exists public.app_settings (
  key text primary key,
  value jsonb not null
);
alter table public.app_settings enable row level security;
drop policy if exists "read settings" on public.app_settings;
drop policy if exists "admin writes settings" on public.app_settings;
create policy "read settings" on public.app_settings for select using (true);
create policy "admin writes settings" on public.app_settings for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- ---------- private settings only the organiser can see (the Discord webhook) ----------
create table if not exists public.secrets (
  key text primary key,
  value text not null check (char_length(value) <= 500)
);
alter table public.secrets enable row level security;
drop policy if exists "admin only secrets" on public.secrets;
create policy "admin only secrets" on public.secrets for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- ---------- Discord posts ----------
-- The site writes a short summary into "announce" when a match is saved;
-- the database forwards it to the Discord webhook, so the webhook stays private.
alter table public.matches add column if not exists announce text
  check (announce is null or char_length(announce) <= 1900);

create or replace function public.post_to_discord(msg text) returns void
language plpgsql security definer set search_path = public, extensions as $$
declare hook text;
begin
  select value into hook from public.secrets where key = 'discord_webhook';
  if hook is null or hook !~ '^https://(ptb\.|canary\.)?discord(app)?\.com/api/webhooks/[0-9]+/[A-Za-z0-9_-]+$' then
    return;
  end if;
  perform net.http_post(
    url := hook,
    body := jsonb_build_object(
      'content', left(msg, 1900),
      'username', 'Rage Quit Rumble',
      'avatar_url', 'https://durrannus.github.io/Rage-quit-rumble/icon.png',
      'allowed_mentions', jsonb_build_object('parse', '[]'::jsonb)),
    headers := '{"Content-Type": "application/json"}'::jsonb);
end $$;
revoke all on function public.post_to_discord(text) from public, anon, authenticated;

create or replace function public.announce_match() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.announce is not null and length(trim(new.announce)) > 0 then
    perform public.post_to_discord(new.announce);
  end if;
  return new;
end $$;
drop trigger if exists announce_match on public.matches;
create trigger announce_match after insert on public.matches
  for each row execute function public.announce_match();

-- The organiser's "Send test message" button.
create or replace function public.discord_test() returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'Only the organiser can do that'; end if;
  perform public.post_to_discord('🔥 **Rage Quit Rumble** is connected. Match results and roasts will land here.');
end $$;
revoke all on function public.discord_test() from public, anon;
grant execute on function public.discord_test() to authenticated;

-- ---------- live updates ----------
do $$ begin
  begin alter publication supabase_realtime add table public.comments; exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table public.app_settings; exception when duplicate_object then null; end;
end $$;
