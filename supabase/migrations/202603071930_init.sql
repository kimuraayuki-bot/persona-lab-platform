-- Persona Lab MVP schema
create extension if not exists pgcrypto;

create table if not exists public.quizzes (
  id uuid primary key default gen_random_uuid(),
  public_id text not null unique,
  creator_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  description text not null default '',
  visibility text not null default 'link_only' check (visibility in ('link_only')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.questions (
  id uuid primary key default gen_random_uuid(),
  quiz_id uuid not null references public.quizzes(id) on delete cascade,
  prompt text not null,
  order_index int not null,
  created_at timestamptz not null default now(),
  unique (quiz_id, order_index)
);

create table if not exists public.choices (
  id uuid primary key default gen_random_uuid(),
  question_id uuid not null references public.questions(id) on delete cascade,
  body text not null,
  order_index int not null,
  ei_delta int not null default 0,
  sn_delta int not null default 0,
  tf_delta int not null default 0,
  jp_delta int not null default 0,
  created_at timestamptz not null default now(),
  unique (question_id, order_index)
);

create table if not exists public.share_links (
  id uuid primary key default gen_random_uuid(),
  quiz_id uuid not null references public.quizzes(id) on delete cascade,
  token_hash text not null unique,
  expires_at timestamptz,
  created_by uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

create table if not exists public.responses (
  id uuid primary key default gen_random_uuid(),
  quiz_id uuid not null references public.quizzes(id) on delete cascade,
  share_link_id uuid references public.share_links(id) on delete set null,
  mbti_type text not null,
  axis_ei int not null,
  axis_sn int not null,
  axis_tf int not null,
  axis_jp int not null,
  fingerprint text,
  created_at timestamptz not null default now()
);

create table if not exists public.response_answers (
  id uuid primary key default gen_random_uuid(),
  response_id uuid not null references public.responses(id) on delete cascade,
  question_id uuid not null references public.questions(id) on delete cascade,
  choice_id uuid not null references public.choices(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (response_id, question_id)
);

create table if not exists public.result_profiles (
  mbti_type text primary key,
  summary text not null
);

insert into public.result_profiles (mbti_type, summary) values
('INTJ', '戦略志向で計画を立てて前進するタイプ'),
('INTP', '分析力が高く概念を深掘りするタイプ'),
('ENTJ', '意思決定が速く目標達成を牽引するタイプ'),
('ENTP', '発想が豊かで変化を楽しむタイプ'),
('INFJ', '洞察力と共感力で周囲を支えるタイプ'),
('INFP', '価値観を大切にし創造性を発揮するタイプ'),
('ENFJ', '対人理解に優れ人を巻き込むタイプ'),
('ENFP', '好奇心旺盛で可能性を広げるタイプ'),
('ISTJ', '誠実で着実に物事を完遂するタイプ'),
('ISFJ', '献身的で細やかな配慮が得意なタイプ'),
('ESTJ', '現実的で運営力に優れるタイプ'),
('ESFJ', '協調性が高く場を整えるタイプ'),
('ISTP', '冷静に状況を捉え実践で解決するタイプ'),
('ISFP', '感性豊かで柔軟に周囲と関わるタイプ'),
('ESTP', '行動力が高く機会を掴むタイプ'),
('ESFP', '明るく社交的で空気を盛り上げるタイプ')
on conflict (mbti_type) do nothing;

create table if not exists public.submission_rate_limits (
  fingerprint text primary key,
  submitted_count int not null default 0,
  window_started_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.quizzes enable row level security;
alter table public.questions enable row level security;
alter table public.choices enable row level security;
alter table public.responses enable row level security;
alter table public.response_answers enable row level security;
alter table public.share_links enable row level security;
alter table public.result_profiles enable row level security;

drop policy if exists quizzes_owner_crud on public.quizzes;
create policy quizzes_owner_crud on public.quizzes
for all to authenticated
using (auth.uid() = creator_id)
with check (auth.uid() = creator_id);

drop policy if exists quizzes_public_read on public.quizzes;
create policy quizzes_public_read on public.quizzes
for select to anon, authenticated
using (visibility = 'link_only');

drop policy if exists questions_owner_crud on public.questions;
create policy questions_owner_crud on public.questions
for all to authenticated
using (
  exists (
    select 1 from public.quizzes q
    where q.id = quiz_id and q.creator_id = auth.uid()
  )
)
with check (
  exists (
    select 1 from public.quizzes q
    where q.id = quiz_id and q.creator_id = auth.uid()
  )
);

drop policy if exists questions_public_read on public.questions;
create policy questions_public_read on public.questions
for select to anon, authenticated
using (
  exists (
    select 1 from public.quizzes q
    where q.id = quiz_id and q.visibility = 'link_only'
  )
);

drop policy if exists choices_owner_crud on public.choices;
create policy choices_owner_crud on public.choices
for all to authenticated
using (
  exists (
    select 1
    from public.questions qu
    join public.quizzes q on q.id = qu.quiz_id
    where qu.id = question_id and q.creator_id = auth.uid()
  )
)
with check (
  exists (
    select 1
    from public.questions qu
    join public.quizzes q on q.id = qu.quiz_id
    where qu.id = question_id and q.creator_id = auth.uid()
  )
);

drop policy if exists choices_public_read on public.choices;
create policy choices_public_read on public.choices
for select to anon, authenticated
using (
  exists (
    select 1
    from public.questions qu
    join public.quizzes q on q.id = qu.quiz_id
    where qu.id = question_id and q.visibility = 'link_only'
  )
);

drop policy if exists responses_owner_select on public.responses;
create policy responses_owner_select on public.responses
for select to authenticated
using (
  exists (
    select 1 from public.quizzes q
    where q.id = quiz_id and q.creator_id = auth.uid()
  )
);

drop policy if exists response_answers_owner_select on public.response_answers;
create policy response_answers_owner_select on public.response_answers
for select to authenticated
using (
  exists (
    select 1
    from public.responses r
    join public.quizzes q on q.id = r.quiz_id
    where r.id = response_id and q.creator_id = auth.uid()
  )
);

drop policy if exists share_links_owner_all on public.share_links;
create policy share_links_owner_all on public.share_links
for all to authenticated
using (created_by = auth.uid())
with check (created_by = auth.uid());

drop policy if exists result_profiles_read on public.result_profiles;
create policy result_profiles_read on public.result_profiles
for select to anon, authenticated
using (true);
