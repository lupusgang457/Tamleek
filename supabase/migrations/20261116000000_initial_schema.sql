create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  name text not null default '',
  email text,
  phone text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

revoke all on table public.profiles from anon, authenticated;
grant select on table public.profiles to authenticated;
grant update (name, phone, updated_at) on table public.profiles to authenticated;

drop policy if exists "Users read their own profile" on public.profiles;
create policy "Users read their own profile"
on public.profiles for select to authenticated
using ((select auth.uid()) = id);

drop policy if exists "Users update their own profile" on public.profiles;
create policy "Users update their own profile"
on public.profiles for update to authenticated
using ((select auth.uid()) = id)
with check (
  (select auth.uid()) = id
);

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, name, email, phone)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'name', ''),
    new.email,
    coalesce(new.raw_user_meta_data ->> 'phone', '')
  );
  return new;
end;
$$;

revoke all on function public.handle_new_user() from public, anon, authenticated;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();

create table if not exists public.kyc_submissions (
  user_id uuid primary key references auth.users (id) on delete cascade,
  first_name text not null,
  last_name text not null,
  birth_year integer not null check (birth_year between 1900 and 2100),
  birth_place text not null,
  city text not null,
  department text not null,
  country text not null,
  identity_number text not null,
  document_path text not null unique,
  status text not null default 'pending'
    check (status in ('pending', 'verified', 'rejected')),
  submitted_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.kyc_submissions enable row level security;

revoke all on table public.kyc_submissions from anon, authenticated;
grant select on table public.kyc_submissions to authenticated;
grant all on table public.kyc_submissions to service_role;

drop policy if exists "Users read their own KYC status"
on public.kyc_submissions;
create policy "Users read their own KYC status"
on public.kyc_submissions for select to authenticated
using ((select auth.uid()) = user_id);

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'kyc-documents',
  'kyc-documents',
  false,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update
set public = false,
    file_size_limit = 5242880,
    allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp'];

drop policy if exists "Users upload their own KYC document"
on storage.objects;
create policy "Users upload their own KYC document"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'kyc-documents'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

drop policy if exists "Users read their own KYC document"
on storage.objects;
create policy "Users read their own KYC document"
on storage.objects for select to authenticated
using (
  bucket_id = 'kyc-documents'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'kyc_submissions'
  ) then
    alter publication supabase_realtime
      add table public.kyc_submissions;
  end if;
end;
$$;
