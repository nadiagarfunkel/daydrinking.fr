-- Run once in Supabase (SQL Editor -> New query -> paste -> Run), after setup.sql.
-- Lets each person remove their own answer, and only their own.
--
-- How: sending an answer now goes through submit_answer(), which hands the
-- browser a secret token. delete_answer() only deletes when given that token.
-- Tokens live in their own table that the page can never read.

create table if not exists public.answer_tokens (
  answer_id bigint primary key references public.answers(id) on delete cascade,
  token     uuid   not null default gen_random_uuid()
);
alter table public.answer_tokens enable row level security;  -- no policies: unreadable from the page

-- Answers can no longer be inserted directly, only through submit_answer().
drop policy if exists "anyone can add answers" on public.answers;

create or replace function public.submit_answer(p_q int, p_text text)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  r public.answers;
  t uuid;
begin
  insert into public.answers (q, text) values (p_q, btrim(p_text)) returning * into r;
  insert into public.answer_tokens (answer_id) values (r.id) returning token into t;
  return json_build_object('id', r.id, 'q', r.q, 'text', r.text, 'created_at', r.created_at, 'token', t);
end $$;

create or replace function public.delete_answer(p_id bigint, p_token uuid)
returns boolean
language sql security definer set search_path = public
as $$
  with d as (
    delete from public.answers a
    using public.answer_tokens k
    where a.id = p_id and k.answer_id = a.id and k.token = p_token
    returning a.id
  )
  select exists (select 1 from d);
$$;

revoke all on function public.submit_answer(int, text) from public;
revoke all on function public.delete_answer(bigint, uuid) from public;
grant execute on function public.submit_answer(int, text) to anon, authenticated;
grant execute on function public.delete_answer(bigint, uuid) to anon, authenticated;
