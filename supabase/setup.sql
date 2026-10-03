-- Run once in Supabase: SQL Editor -> New query -> paste -> Run.

create table if not exists public.answers (
  id         bigint generated always as identity primary key,
  q          smallint    not null check (q between 0 and 21),          -- index into PROMPTS
  text       text        not null check (char_length(btrim(text)) between 1 and 30),
  created_at timestamptz not null default now()
);

-- Row Level Security: visitors (anon key) can read and add answers,
-- but never edit or delete them (no update/delete policies).
alter table public.answers enable row level security;

drop policy if exists "anyone can read answers" on public.answers;
create policy "anyone can read answers"
  on public.answers for select
  to anon, authenticated
  using (true);

drop policy if exists "anyone can add answers" on public.answers;
create policy "anyone can add answers"
  on public.answers for insert
  to anon, authenticated
  with check (true);

-- Live updates: push new rows to everyone's open page.
alter publication supabase_realtime add table public.answers;
