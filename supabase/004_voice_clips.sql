-- Rage Quit Rumble: voice comms clips.
-- Run once in Supabase > SQL Editor (paste the whole file, press Run). Safe to run again.

-- Public bucket for short audio clips (max 2 MB each, WAV/WebM/Ogg/MP3 only).
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('clips', 'clips', true, 2097152, array['audio/wav','audio/x-wav','audio/webm','audio/ogg','audio/mpeg'])
on conflict (id) do update set public = true, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "clips are public" on storage.objects;
drop policy if exists "approved upload clips" on storage.objects;
drop policy if exists "owner or organiser deletes clips" on storage.objects;
create policy "clips are public" on storage.objects for select using (bucket_id = 'clips');
create policy "approved upload clips" on storage.objects for insert to authenticated
  with check (bucket_id = 'clips' and public.is_approved());
create policy "owner or organiser deletes clips" on storage.objects for delete to authenticated
  using (bucket_id = 'clips' and (owner = auth.uid() or public.is_admin()));

-- One row per clip, attached to a match.
create table if not exists public.clips (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references public.matches(id) on delete cascade,
  path text not null unique check (path ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}\.(wav|webm|ogg|mp3)$'),
  label text check (label is null or char_length(label) <= 80),
  pid uuid references public.players(id) on delete set null,
  at_s real,
  dur_s real check (dur_s is null or dur_s <= 30),
  created_by uuid not null default auth.uid() references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);
alter table public.clips enable row level security;
drop policy if exists "read clips" on public.clips;
drop policy if exists "approved add clips" on public.clips;
drop policy if exists "owner or organiser removes clips" on public.clips;
drop policy if exists "owner or organiser edits clips" on public.clips;
create policy "read clips" on public.clips for select using (true);
create policy "approved add clips" on public.clips for insert to authenticated
  with check (public.is_approved() and created_by = auth.uid());
create policy "owner or organiser edits clips" on public.clips for update to authenticated
  using (created_by = auth.uid() or public.is_admin()) with check (created_by = auth.uid() or public.is_admin());
create policy "owner or organiser removes clips" on public.clips for delete to authenticated
  using (created_by = auth.uid() or public.is_admin());

do $$ begin
  begin alter publication supabase_realtime add table public.clips; exception when duplicate_object then null; end;
end $$;
