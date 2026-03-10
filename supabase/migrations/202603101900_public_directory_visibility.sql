alter table public.quizzes
  drop constraint if exists quizzes_visibility_check;

update public.quizzes
set visibility = 'share_link'
where visibility = 'link_only';

alter table public.quizzes
  alter column visibility set default 'share_link';

alter table public.quizzes
  add constraint quizzes_visibility_check
  check (visibility in ('share_link', 'directory_public'));

drop policy if exists quizzes_public_read on public.quizzes;
create policy quizzes_public_read on public.quizzes
for select to anon, authenticated
using (visibility = 'directory_public');

drop policy if exists questions_public_read on public.questions;
create policy questions_public_read on public.questions
for select to anon, authenticated
using (
  exists (
    select 1 from public.quizzes q
    where q.id = quiz_id and q.visibility = 'directory_public'
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
    where qu.id = question_id and q.visibility = 'directory_public'
  )
);

drop policy if exists quiz_axes_public_read on public.quiz_axes;
create policy quiz_axes_public_read on public.quiz_axes
for select to anon, authenticated
using (
  exists (
    select 1 from public.quizzes q
    where q.id = quiz_id and q.visibility = 'directory_public'
  )
);

drop policy if exists quiz_result_profiles_public_read on public.quiz_result_profiles;
create policy quiz_result_profiles_public_read on public.quiz_result_profiles
for select to anon, authenticated
using (
  exists (
    select 1 from public.quizzes q
    where q.id = quiz_id and q.visibility = 'directory_public'
  )
);

drop policy if exists quiz_response_stats_public_select on public.quiz_response_stats;
create policy quiz_response_stats_public_select on public.quiz_response_stats
for select to anon, authenticated
using (
  exists (
    select 1 from public.quizzes q
    where q.id = quiz_id and q.visibility = 'directory_public'
  )
);

drop policy if exists quiz_result_stats_public_select on public.quiz_result_stats;
create policy quiz_result_stats_public_select on public.quiz_result_stats
for select to anon, authenticated
using (
  exists (
    select 1 from public.quizzes q
    where q.id = quiz_id and q.visibility = 'directory_public'
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
    where qu.id = question_id and q.visibility = 'directory_public'
  )
);
