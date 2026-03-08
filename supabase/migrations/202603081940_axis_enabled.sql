alter table public.quiz_axes
add column if not exists is_enabled boolean not null default true;

update public.quiz_axes
set is_enabled = true
where is_enabled is distinct from true;
