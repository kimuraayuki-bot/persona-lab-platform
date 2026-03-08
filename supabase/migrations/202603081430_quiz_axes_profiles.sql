-- Per-quiz axis code settings and per-result profile settings

create table if not exists public.quiz_axes (
  quiz_id uuid not null references public.quizzes(id) on delete cascade,
  axis_key text not null check (axis_key in ('ei', 'sn', 'tf', 'jp')),
  order_index int not null,
  positive_code text not null,
  negative_code text not null,
  positive_label text not null,
  negative_label text not null,
  tie_break text not null default 'positive' check (tie_break in ('positive', 'negative')),
  created_at timestamptz not null default now(),
  primary key (quiz_id, axis_key),
  unique (quiz_id, order_index)
);

create table if not exists public.quiz_result_profiles (
  id uuid primary key default gen_random_uuid(),
  quiz_id uuid not null references public.quizzes(id) on delete cascade,
  result_code text not null,
  role_name text not null,
  summary text not null,
  detail text not null default '',
  image_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (quiz_id, result_code)
);

alter table public.quiz_axes enable row level security;
alter table public.quiz_result_profiles enable row level security;

drop policy if exists quiz_axes_owner_all on public.quiz_axes;
create policy quiz_axes_owner_all on public.quiz_axes
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

drop policy if exists quiz_axes_public_read on public.quiz_axes;
create policy quiz_axes_public_read on public.quiz_axes
for select to anon, authenticated
using (
  exists (
    select 1 from public.quizzes q
    where q.id = quiz_id and q.visibility = 'link_only'
  )
);

drop policy if exists quiz_result_profiles_owner_all on public.quiz_result_profiles;
create policy quiz_result_profiles_owner_all on public.quiz_result_profiles
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

drop policy if exists quiz_result_profiles_public_read on public.quiz_result_profiles;
create policy quiz_result_profiles_public_read on public.quiz_result_profiles
for select to anon, authenticated
using (
  exists (
    select 1 from public.quizzes q
    where q.id = quiz_id and q.visibility = 'link_only'
  )
);

insert into public.quiz_axes (
  quiz_id,
  axis_key,
  order_index,
  positive_code,
  negative_code,
  positive_label,
  negative_label,
  tie_break
)
select
  q.id,
  defs.axis_key,
  defs.order_index,
  defs.positive_code,
  defs.negative_code,
  defs.positive_code,
  defs.negative_code,
  'positive'
from public.quizzes q
cross join (
  values
    ('ei', 0, 'E', 'I'),
    ('sn', 1, 'S', 'N'),
    ('tf', 2, 'T', 'F'),
    ('jp', 3, 'J', 'P')
) as defs(axis_key, order_index, positive_code, negative_code)
on conflict (quiz_id, axis_key) do nothing;

with codes(code) as (
  values
    ('ESTJ'), ('ESTP'), ('ESFJ'), ('ESFP'),
    ('ENTJ'), ('ENTP'), ('ENFJ'), ('ENFP'),
    ('ISTJ'), ('ISTP'), ('ISFJ'), ('ISFP'),
    ('INTJ'), ('INTP'), ('INFJ'), ('INFP')
)
insert into public.quiz_result_profiles (
  quiz_id,
  result_code,
  role_name,
  summary,
  detail
)
select
  q.id,
  c.code,
  c.code || 'タイプ',
  'この診断で導かれた結果タイプです。',
  'この説明は作成者が編集できます。'
from public.quizzes q
cross join codes c
on conflict (quiz_id, result_code) do nothing;
