-- CM + AI Health Connect: core schema and least-privilege RLS baseline.
-- Run in Supabase SQL Editor. Never put the service_role key in the browser.
create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default '',
  phone text,
  role text not null default 'cm' check (role in ('admin','supervisor','cm','flw','viewer')),
  assigned_uc_ids uuid[] not null default '{}',
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.areas (
  id uuid primary key default gen_random_uuid(), name text not null, uc_code text not null unique,
  district text not null default '', province text not null default '', created_at timestamptz not null default now()
);
create table if not exists public.campaigns (
  id uuid primary key default gen_random_uuid(), name text not null,
  campaign_type text not null check (campaign_type in ('NID','SNID','EPI','other')),
  starts_on date not null, ends_on date not null, target_children integer not null default 0 check(target_children>=0),
  status text not null default 'planned' check(status in ('planned','active','completed','cancelled')),
  area_id uuid references public.areas(id) on delete set null, created_by uuid references auth.users(id), created_at timestamptz not null default now(),
  check(ends_on>=starts_on)
);
create table if not exists public.team_members (
  id uuid primary key default gen_random_uuid(), user_id uuid references auth.users(id) on delete set null,
  full_name text not null, role_title text not null default 'FLW', phone text, area_id uuid references public.areas(id) on delete set null,
  is_active boolean not null default true, created_at timestamptz not null default now()
);
create table if not exists public.daily_activities (
  id uuid primary key default gen_random_uuid(), user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  activity_date date not null default current_date, activity_type text not null, area_name text not null default '',
  area_id uuid references public.areas(id) on delete set null, campaign_id uuid references public.campaigns(id) on delete set null,
  notes text not null default '', status text not null default 'completed' check(status in ('completed','pending','follow_up')),
  created_at timestamptz not null default now()
);
-- Child data is sensitive. Limit access to authorized users; never collect more identifiers than required by local policy.
create table if not exists public.children (
  id uuid primary key default gen_random_uuid(), area_id uuid references public.areas(id) on delete set null,
  campaign_id uuid references public.campaigns(id) on delete set null, local_record_code text not null,
  age_months integer check(age_months between 0 and 240), vaccination_status text not null default 'pending'
    check(vaccination_status in ('vaccinated','pending','still_na','refusal','ineligible','unknown')),
  last_visit_on date, next_follow_up_on date, created_by uuid references auth.users(id), created_at timestamptz not null default now(),
  unique(area_id, local_record_code)
);
create table if not exists public.vaccination_events (
  id uuid primary key default gen_random_uuid(), child_id uuid not null references public.children(id) on delete cascade,
  campaign_id uuid references public.campaigns(id) on delete set null, vaccine_name text not null, administered_on date not null,
  dose_number integer, recorded_by uuid not null default auth.uid() references auth.users(id), source text not null default 'verified_register',
  created_at timestamptz not null default now()
);
create table if not exists public.follow_ups (
  id uuid primary key default gen_random_uuid(), child_id uuid references public.children(id) on delete cascade,
  area_id uuid references public.areas(id) on delete set null, follow_up_type text not null check(follow_up_type in ('still_na','refusal','other')),
  due_on date, outcome text, status text not null default 'open' check(status in ('open','scheduled','resolved','escalated')),
  assigned_to uuid references auth.users(id), notes text not null default '', created_by uuid not null default auth.uid() references auth.users(id), created_at timestamptz not null default now()
);
create table if not exists public.community_sessions (
  id uuid primary key default gen_random_uuid(), session_type text not null check(session_type in ('school','madrassa','community','other')),
  title text not null, area_id uuid references public.areas(id) on delete set null, held_on date not null,
  attendees_count integer not null default 0 check(attendees_count>=0), partner_name text, notes text not null default '', created_by uuid not null default auth.uid() references auth.users(id), created_at timestamptz not null default now()
);
create table if not exists public.partners (
  id uuid primary key default gen_random_uuid(), name text not null, partner_type text not null check(partner_type in ('influencer','ngo','community_leader','other')),
  area_id uuid references public.areas(id) on delete set null, contact_name text, contact_phone text, created_at timestamptz not null default now()
);
create table if not exists public.engagements (
  id uuid primary key default gen_random_uuid(), partner_id uuid references public.partners(id) on delete set null,
  area_id uuid references public.areas(id) on delete set null, engaged_on date not null default current_date,
  activity text not null, next_follow_up_on date, notes text not null default '', created_by uuid not null default auth.uid() references auth.users(id), created_at timestamptz not null default now()
);

create or replace function public.current_role() returns text language sql stable security definer set search_path=public as $$
  select coalesce((select role from public.profiles where id=auth.uid()), 'viewer');
$$;
create or replace function public.is_staff() returns boolean language sql stable security definer set search_path=public as $$
  select public.current_role() in ('admin','supervisor','cm','flw');
$$;
create or replace function public.can_manage() returns boolean language sql stable security definer set search_path=public as $$
  select public.current_role() in ('admin','supervisor');
$$;

alter table public.profiles enable row level security;
alter table public.areas enable row level security;
alter table public.campaigns enable row level security;
alter table public.team_members enable row level security;
alter table public.daily_activities enable row level security;
alter table public.children enable row level security;
alter table public.vaccination_events enable row level security;
alter table public.follow_ups enable row level security;
alter table public.community_sessions enable row level security;
alter table public.partners enable row level security;
alter table public.engagements enable row level security;

create policy "profile self read" on public.profiles for select to authenticated using (id=auth.uid() or public.can_manage());
create policy "profile self update" on public.profiles for update to authenticated using(id=auth.uid()) with check(id=auth.uid());
create policy "admins manage profiles" on public.profiles for all to authenticated using(public.current_role()='admin') with check(public.current_role()='admin');
create policy "staff read areas" on public.areas for select to authenticated using(public.is_staff());
create policy "managers manage areas" on public.areas for all to authenticated using(public.can_manage()) with check(public.can_manage());
create policy "staff read campaigns" on public.campaigns for select to authenticated using(public.is_staff());
create policy "managers manage campaigns" on public.campaigns for all to authenticated using(public.can_manage()) with check(public.can_manage());
create policy "staff read team" on public.team_members for select to authenticated using(public.is_staff());
create policy "managers manage team" on public.team_members for all to authenticated using(public.can_manage()) with check(public.can_manage());
create policy "activities read own or manager" on public.daily_activities for select to authenticated using(user_id=auth.uid() or public.can_manage());
create policy "activities insert own" on public.daily_activities for insert to authenticated with check(user_id=auth.uid() and public.is_staff());
create policy "activities update own or manager" on public.daily_activities for update to authenticated using(user_id=auth.uid() or public.can_manage()) with check(user_id=auth.uid() or public.can_manage());
create policy "activities delete managers" on public.daily_activities for delete to authenticated using(public.can_manage());
create policy "authorized staff access child records" on public.children for all to authenticated using(public.current_role() in ('admin','supervisor','cm','flw')) with check(public.current_role() in ('admin','supervisor','cm','flw'));
create policy "authorized staff access vaccination events" on public.vaccination_events for all to authenticated using(public.current_role() in ('admin','supervisor','cm','flw')) with check(public.current_role() in ('admin','supervisor','cm','flw'));
create policy "authorized staff access followups" on public.follow_ups for all to authenticated using(public.current_role() in ('admin','supervisor','cm','flw')) with check(public.current_role() in ('admin','supervisor','cm','flw'));
create policy "staff read sessions" on public.community_sessions for select to authenticated using(public.is_staff());
create policy "staff create sessions" on public.community_sessions for insert to authenticated with check(created_by=auth.uid() and public.is_staff());
create policy "managers update sessions" on public.community_sessions for update to authenticated using(public.can_manage()) with check(public.can_manage());
create policy "staff read partners" on public.partners for select to authenticated using(public.is_staff());
create policy "managers manage partners" on public.partners for all to authenticated using(public.can_manage()) with check(public.can_manage());
create policy "staff read engagements" on public.engagements for select to authenticated using(public.is_staff());
create policy "staff create engagements" on public.engagements for insert to authenticated with check(created_by=auth.uid() and public.is_staff());
create policy "managers update engagements" on public.engagements for update to authenticated using(public.can_manage()) with check(public.can_manage());

create index if not exists daily_activities_user_date_idx on public.daily_activities(user_id,activity_date desc);
create index if not exists children_area_status_idx on public.children(area_id,vaccination_status);
create index if not exists follow_ups_status_due_idx on public.follow_ups(status,due_on);
create index if not exists vaccination_child_date_idx on public.vaccination_events(child_id,administered_on desc);
