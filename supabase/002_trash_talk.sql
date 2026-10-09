-- Rage Quit Rumble: trash talk under matches.
-- Run once in Supabase > SQL Editor (paste the whole file, press Run).

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
