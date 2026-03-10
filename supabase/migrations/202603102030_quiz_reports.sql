create table if not exists public.quiz_reports (
  id uuid primary key default gen_random_uuid(),
  quiz_id uuid not null references public.quizzes(id) on delete cascade,
  quiz_public_id text not null,
  source text not null check (source in ('web_ranking', 'web_quiz', 'ios_ranking', 'ios_quiz', 'ios_result')),
  reason text not null check (reason in ('illegal', 'sexual', 'violent', 'harassment', 'copyright', 'spam', 'other')),
  details text not null default '',
  reporter_email text,
  page_url text,
  app_version text,
  fingerprint text,
  status text not null default 'open' check (status in ('open', 'reviewing', 'resolved', 'dismissed')),
  created_at timestamptz not null default now()
);

create index if not exists quiz_reports_quiz_id_idx on public.quiz_reports (quiz_id, created_at desc);
create index if not exists quiz_reports_status_idx on public.quiz_reports (status, created_at desc);

create table if not exists public.report_rate_limits (
  fingerprint text primary key,
  submitted_count int not null default 0,
  window_started_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.quiz_reports enable row level security;
alter table public.report_rate_limits enable row level security;
