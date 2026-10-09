-- Rage Quit Rumble: database setup.
-- Paste this whole file into Supabase > SQL Editor > New query, and press Run.
-- Safe to run once on a new project.

create table if not exists public.admins (
  user_id uuid primary key references auth.users(id) on delete cascade
);

create table if not exists public.games (
  id text primary key,
  config jsonb not null,
  created_at timestamptz not null default now()
);

create table if not exists public.players (
  id uuid primary key default gen_random_uuid(),
  tag text not null check (char_length(tag) between 1 and 32),
  user_id uuid unique references auth.users(id) on delete set null,
  approved boolean not null default false,
  avatar text,
  created_at timestamptz not null default now()
);

create table if not exists public.matches (
  id uuid primary key default gen_random_uuid(),
  game text not null references public.games(id) on delete cascade,
  season text not null,
  played_at timestamptz not null,
  winner text,
  note text,
  entries jsonb not null default '[]'::jsonb,
  logged_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

-- Who may do what
create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.admins where user_id = auth.uid());
$$;

create or replace function public.is_approved() returns boolean
language sql stable security definer set search_path = public as $$
  select public.is_admin()
      or exists (select 1 from public.players where user_id = auth.uid() and approved);
$$;

-- The first person to log in becomes the organiser.
create or replace function public.first_user_is_admin() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from public.admins) then
    insert into public.admins (user_id) values (new.id);
  end if;
  return new;
end $$;
drop trigger if exists on_first_user on auth.users;
create trigger on_first_user after insert on auth.users
  for each row execute function public.first_user_is_admin();

-- Only the organiser can approve players. Joining or claiming a name
-- always starts unapproved.
create or replace function public.players_guard() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then
    if tg_op = 'INSERT' then
      new.approved := false;
    elsif new.user_id is distinct from old.user_id then
      new.approved := false;
    else
      new.approved := old.approved;
    end if;
  end if;
  return new;
end $$;
drop trigger if exists players_guard on public.players;
create trigger players_guard before insert or update on public.players
  for each row execute function public.players_guard();

alter table public.admins  enable row level security;
alter table public.games   enable row level security;
alter table public.players enable row level security;
alter table public.matches enable row level security;

-- Everyone can read the scoreboard.
create policy "read games"   on public.games   for select using (true);
create policy "read players" on public.players for select using (true);
create policy "read matches" on public.matches for select using (true);

-- Games: organiser only.
create policy "admin writes games" on public.games for all
  using (public.is_admin()) with check (public.is_admin());

-- Players: join yourself, claim an unclaimed name, rename yourself.
-- The organiser can add, edit and approve anyone.
create policy "add players" on public.players for insert to authenticated
  with check (public.is_admin() or user_id = auth.uid());
create policy "edit players" on public.players for update to authenticated
  using (public.is_admin() or user_id = auth.uid() or user_id is null)
  with check (public.is_admin() or user_id = auth.uid());
create policy "admin deletes players" on public.players for delete to authenticated
  using (public.is_admin());

-- Matches: approved players and the organiser.
create policy "approved log matches" on public.matches for insert to authenticated
  with check (public.is_approved());
create policy "approved edit matches" on public.matches for update to authenticated
  using (public.is_approved()) with check (public.is_approved());
create policy "approved delete matches" on public.matches for delete to authenticated
  using (public.is_approved());

-- Live updates
alter publication supabase_realtime add table public.games, public.players, public.matches;

-- League of Legends to start with
insert into public.games (id, config) values ('league-of-legends', '{
  "name":"League of Legends","short":"LoL","format":"teams","teamSize":5,"pickLabel":"Champion",
  "stats":[{"key":"k","label":"Kills"},{"key":"d","label":"Deaths"},{"key":"a","label":"Assists"},{"key":"cs","label":"CS"}],
  "kda":{"k":"k","d":"d","a":"a"},"shameStat":"d","mvpStat":"kda",
  "points":{"win":3,"loss":0,"mvp":1},"order":1
}'::jsonb) on conflict (id) do nothing;

-- Trash talk (same as 002_trash_talk.sql)
create table if not exists public.comments (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references public.matches(id) on delete cascade,
  author uuid not null default auth.uid() references auth.users(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 280),
  created_at timestamptz not null default now()
);

alter table public.comments enable row level security;

create policy "read comments" on public.comments for select using (true);
create policy "approved post comments" on public.comments for insert to authenticated
  with check (public.is_approved() and author = auth.uid());
create policy "delete own comments" on public.comments for delete to authenticated
  using (author = auth.uid() or public.is_admin());

alter publication supabase_realtime add table public.comments;
