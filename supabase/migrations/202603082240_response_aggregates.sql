create table if not exists public.quiz_response_stats (
  quiz_id uuid primary key references public.quizzes(id) on delete cascade,
  total_responses bigint not null default 0,
  updated_at timestamptz not null default now()
);

create table if not exists public.quiz_result_stats (
  quiz_id uuid not null references public.quizzes(id) on delete cascade,
  result_code text not null,
  response_count bigint not null default 0,
  updated_at timestamptz not null default now(),
  primary key (quiz_id, result_code)
);

create table if not exists public.question_choice_stats (
  question_id uuid not null references public.questions(id) on delete cascade,
  choice_id uuid not null references public.choices(id) on delete cascade,
  response_count bigint not null default 0,
  updated_at timestamptz not null default now(),
  primary key (question_id, choice_id)
);

alter table public.quiz_response_stats enable row level security;
alter table public.quiz_result_stats enable row level security;
alter table public.question_choice_stats enable row level security;

drop policy if exists quiz_response_stats_owner_select on public.quiz_response_stats;
create policy quiz_response_stats_owner_select on public.quiz_response_stats
for select to authenticated
using (
  exists (
    select 1 from public.quizzes q
    where q.id = quiz_id and q.creator_id = auth.uid()
  )
);

drop policy if exists quiz_response_stats_public_select on public.quiz_response_stats;
create policy quiz_response_stats_public_select on public.quiz_response_stats
for select to anon, authenticated
using (
  exists (
    select 1 from public.quizzes q
    where q.id = quiz_id and q.visibility = 'link_only'
  )
);

drop policy if exists quiz_result_stats_owner_select on public.quiz_result_stats;
create policy quiz_result_stats_owner_select on public.quiz_result_stats
for select to authenticated
using (
  exists (
    select 1 from public.quizzes q
    where q.id = quiz_id and q.creator_id = auth.uid()
  )
);

drop policy if exists quiz_result_stats_public_select on public.quiz_result_stats;
create policy quiz_result_stats_public_select on public.quiz_result_stats
for select to anon, authenticated
using (
  exists (
    select 1 from public.quizzes q
    where q.id = quiz_id and q.visibility = 'link_only'
  )
);

drop policy if exists question_choice_stats_owner_select on public.question_choice_stats;
create policy question_choice_stats_owner_select on public.question_choice_stats
for select to authenticated
using (
  exists (
    select 1
    from public.questions qu
    join public.quizzes q on q.id = qu.quiz_id
    where qu.id = question_id and q.creator_id = auth.uid()
  )
);

drop policy if exists question_choice_stats_public_select on public.question_choice_stats;
create policy question_choice_stats_public_select on public.question_choice_stats
for select to anon, authenticated
using (
  exists (
    select 1
    from public.questions qu
    join public.quizzes q on q.id = qu.quiz_id
    where qu.id = question_id and q.visibility = 'link_only'
  )
);

create or replace function public.record_quiz_aggregate_response(
  p_quiz_id uuid,
  p_result_code text,
  p_answers jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.quiz_response_stats (
    quiz_id,
    total_responses,
    updated_at
  )
  values (
    p_quiz_id,
    1,
    now()
  )
  on conflict (quiz_id) do update
  set total_responses = public.quiz_response_stats.total_responses + 1,
      updated_at = now();

  insert into public.quiz_result_stats (
    quiz_id,
    result_code,
    response_count,
    updated_at
  )
  values (
    p_quiz_id,
    upper(p_result_code),
    1,
    now()
  )
  on conflict (quiz_id, result_code) do update
  set response_count = public.quiz_result_stats.response_count + 1,
      updated_at = now();

  insert into public.question_choice_stats (
    question_id,
    choice_id,
    response_count,
    updated_at
  )
  select
    (item ->> 'question_id')::uuid,
    (item ->> 'choice_id')::uuid,
    1,
    now()
  from jsonb_array_elements(p_answers) as item
  on conflict (question_id, choice_id) do update
  set response_count = public.question_choice_stats.response_count + 1,
      updated_at = now();
end;
$$;

grant execute on function public.record_quiz_aggregate_response(uuid, text, jsonb) to service_role;
