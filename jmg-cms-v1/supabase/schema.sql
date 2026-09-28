-- ============================================================
-- JMG CMS v1 · Multi-cliente / HTML-CSS-JS libre
-- Ejecutar en un proyecto NUEVO de Supabase (SQL Editor > Run)
-- ============================================================

create extension if not exists pgcrypto;

-- ---------- Usuarios ----------
create table if not exists public.jmg_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default '',
  system_role text not null default 'client' check (system_role in ('superadmin','staff','client')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create or replace function public.jmg_handle_new_user()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  insert into public.jmg_profiles(user_id,display_name)
  values(new.id, coalesce(new.raw_user_meta_data->>'display_name', split_part(coalesce(new.email,''),'@',1)))
  on conflict (user_id) do nothing;
  return new;
end $$;

drop trigger if exists on_auth_user_created_jmg on auth.users;
create trigger on_auth_user_created_jmg
after insert on auth.users for each row execute procedure public.jmg_handle_new_user();

-- ---------- Clientes / organizaciones ----------
create table if not exists public.jmg_organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique,
  status text not null default 'active' check(status in ('active','paused','archived')),
  notes text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.jmg_memberships (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.jmg_organizations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'client' check(role in ('owner','editor','client')),
  created_at timestamptz not null default now(),
  unique(organization_id,user_id)
);

-- ---------- Webs ----------
create table if not exists public.jmg_sites (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.jmg_organizations(id) on delete cascade,
  name text not null,
  slug text not null unique,
  domain text not null default '',
  status text not null default 'draft' check(status in ('draft','active','paused')),
  netlify_site_id text not null default '',
  netlify_site_name text not null default '',
  published_url text not null default '',
  settings jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.jmg_pages (
  id uuid primary key default gen_random_uuid(),
  site_id uuid not null references public.jmg_sites(id) on delete cascade,
  source_path text not null,
  title text not null default '',
  nav_label text not null default '',
  seo_title text not null default '',
  seo_description text not null default '',
  canonical_url text not null default '',
  og_image text not null default '',
  robots_index boolean not null default true,
  robots_follow boolean not null default true,
  client_seo_editable boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(site_id,source_path)
);

-- Archivos originales subidos por JMG. Los bytes viven en Storage / jmg-source.
create table if not exists public.jmg_files (
  id uuid primary key default gen_random_uuid(),
  site_id uuid not null references public.jmg_sites(id) on delete cascade,
  path text not null,
  content_type text not null default 'application/octet-stream',
  size_bytes bigint not null default 0,
  checksum text not null default '',
  updated_at timestamptz not null default now(),
  unique(site_id,path)
);

-- Campos detectados a partir de data-jmg.
create table if not exists public.jmg_fields (
  id uuid primary key default gen_random_uuid(),
  site_id uuid not null references public.jmg_sites(id) on delete cascade,
  page_path text not null,
  field_key text not null,
  field_type text not null check(field_type in ('text','richtext','image','link','number','color','toggle','html','repeater')),
  label text not null default '',
  group_name text not null default 'Contenido',
  sort_order integer not null default 0,
  client_editable boolean not null default true,
  settings jsonb not null default '{}'::jsonb,
  default_value jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(site_id,field_key)
);

create table if not exists public.jmg_content (
  id uuid primary key default gen_random_uuid(),
  site_id uuid not null references public.jmg_sites(id) on delete cascade,
  field_key text not null,
  value jsonb,
  updated_by uuid references auth.users(id) on delete set null,
  updated_at timestamptz not null default now(),
  unique(site_id,field_key)
);

create table if not exists public.jmg_deploys (
  id uuid primary key default gen_random_uuid(),
  site_id uuid not null references public.jmg_sites(id) on delete cascade,
  status text not null default 'queued' check(status in ('queued','building','ready','failed')),
  provider text not null default 'netlify',
  provider_deploy_id text not null default '',
  deploy_url text not null default '',
  message text not null default '',
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  finished_at timestamptz
);

create table if not exists public.jmg_audit_log (
  id bigint generated always as identity primary key,
  user_id uuid references auth.users(id) on delete set null,
  site_id uuid references public.jmg_sites(id) on delete cascade,
  action text not null,
  detail jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

-- ---------- Helpers de permisos ----------
create or replace function public.jmg_is_staff()
returns boolean language sql stable security definer set search_path=public as $$
  select exists(select 1 from public.jmg_profiles where user_id=auth.uid() and system_role in ('superadmin','staff'));
$$;

create or replace function public.jmg_can_access_org(org uuid)
returns boolean language sql stable security definer set search_path=public as $$
  select public.jmg_is_staff() or exists(
    select 1 from public.jmg_memberships where organization_id=org and user_id=auth.uid()
  );
$$;

create or replace function public.jmg_can_manage_org(org uuid)
returns boolean language sql stable security definer set search_path=public as $$
  select public.jmg_is_staff() or exists(
    select 1 from public.jmg_memberships where organization_id=org and user_id=auth.uid() and role in ('owner','editor')
  );
$$;

create or replace function public.jmg_can_access_site(site uuid)
returns boolean language sql stable security definer set search_path=public as $$
  select exists(select 1 from public.jmg_sites s where s.id=site and public.jmg_can_access_org(s.organization_id));
$$;

create or replace function public.jmg_can_manage_site(site uuid)
returns boolean language sql stable security definer set search_path=public as $$
  select exists(select 1 from public.jmg_sites s where s.id=site and public.jmg_can_manage_org(s.organization_id));
$$;

create or replace function public.jmg_can_edit_field(site uuid, fkey text)
returns boolean language sql stable security definer set search_path=public as $$
  select public.jmg_is_staff() or (
    public.jmg_can_access_site(site) and exists(
      select 1 from public.jmg_fields f where f.site_id=site and f.field_key=fkey and f.client_editable=true
    )
  );
$$;

-- ---------- RLS ----------
alter table public.jmg_profiles enable row level security;
alter table public.jmg_organizations enable row level security;
alter table public.jmg_memberships enable row level security;
alter table public.jmg_sites enable row level security;
alter table public.jmg_pages enable row level security;
alter table public.jmg_files enable row level security;
alter table public.jmg_fields enable row level security;
alter table public.jmg_content enable row level security;
alter table public.jmg_deploys enable row level security;
alter table public.jmg_audit_log enable row level security;

create policy "profiles self or staff read" on public.jmg_profiles for select to authenticated
using(user_id=auth.uid() or public.jmg_is_staff());
create policy "staff manage profiles" on public.jmg_profiles for all to authenticated
using(public.jmg_is_staff()) with check(public.jmg_is_staff());

create policy "org access" on public.jmg_organizations for select to authenticated using(public.jmg_can_access_org(id));
create policy "staff create org" on public.jmg_organizations for insert to authenticated with check(public.jmg_is_staff());
create policy "org manage" on public.jmg_organizations for update to authenticated using(public.jmg_can_manage_org(id)) with check(public.jmg_can_manage_org(id));
create policy "staff delete org" on public.jmg_organizations for delete to authenticated using(public.jmg_is_staff());

create policy "membership access" on public.jmg_memberships for select to authenticated
using(public.jmg_is_staff() or user_id=auth.uid() or public.jmg_can_manage_org(organization_id));
create policy "membership manage" on public.jmg_memberships for all to authenticated
using(public.jmg_can_manage_org(organization_id)) with check(public.jmg_can_manage_org(organization_id));

create policy "site access" on public.jmg_sites for select to authenticated using(public.jmg_can_access_org(organization_id));
create policy "site insert" on public.jmg_sites for insert to authenticated with check(public.jmg_can_manage_org(organization_id));
create policy "site update" on public.jmg_sites for update to authenticated using(public.jmg_can_manage_org(organization_id)) with check(public.jmg_can_manage_org(organization_id));
create policy "site delete" on public.jmg_sites for delete to authenticated using(public.jmg_can_manage_org(organization_id));

create policy "pages access" on public.jmg_pages for select to authenticated using(public.jmg_can_access_site(site_id));
create policy "pages manage" on public.jmg_pages for all to authenticated using(public.jmg_can_manage_site(site_id)) with check(public.jmg_can_manage_site(site_id));


-- Los clientes actualizan SOLO columnas SEO mediante esta RPC; no pueden alterar source_path ni estructura.
create or replace function public.jmg_update_client_seo(
  p_page_id uuid, p_title text, p_description text, p_canonical text, p_og_image text, p_index boolean, p_follow boolean
) returns void language plpgsql security definer set search_path=public as $$
declare p public.jmg_pages;
begin
  select * into p from public.jmg_pages where id=p_page_id;
  if p.id is null or not p.client_seo_editable or not public.jmg_can_access_site(p.site_id) then
    raise exception 'No autorizado';
  end if;
  update public.jmg_pages set seo_title=coalesce(p_title,''), seo_description=coalesce(p_description,''), canonical_url=coalesce(p_canonical,''), og_image=coalesce(p_og_image,''), robots_index=p_index, robots_follow=p_follow, updated_at=now() where id=p_page_id;
end $$;

grant execute on function public.jmg_update_client_seo(uuid,text,text,text,text,boolean,boolean) to authenticated;

create policy "files access" on public.jmg_files for select to authenticated using(public.jmg_can_access_site(site_id));
create policy "files manage" on public.jmg_files for all to authenticated using(public.jmg_can_manage_site(site_id)) with check(public.jmg_can_manage_site(site_id));

create policy "fields access" on public.jmg_fields for select to authenticated using(public.jmg_can_access_site(site_id));
create policy "fields manage" on public.jmg_fields for all to authenticated using(public.jmg_can_manage_site(site_id)) with check(public.jmg_can_manage_site(site_id));

create policy "content access" on public.jmg_content for select to authenticated using(public.jmg_can_access_site(site_id));
create policy "content insert" on public.jmg_content for insert to authenticated
with check(public.jmg_can_edit_field(site_id,field_key));
create policy "content update" on public.jmg_content for update to authenticated
using(public.jmg_can_edit_field(site_id,field_key)) with check(public.jmg_can_edit_field(site_id,field_key));
create policy "content delete staff" on public.jmg_content for delete to authenticated using(public.jmg_can_manage_site(site_id));

create policy "deploy access" on public.jmg_deploys for select to authenticated using(public.jmg_can_access_site(site_id));
create policy "deploy insert" on public.jmg_deploys for insert to authenticated with check(public.jmg_can_manage_site(site_id));
create policy "deploy update staff" on public.jmg_deploys for update to authenticated using(public.jmg_can_manage_site(site_id));

create policy "audit access" on public.jmg_audit_log for select to authenticated using(public.jmg_is_staff() or public.jmg_can_access_site(site_id));
create policy "audit insert" on public.jmg_audit_log for insert to authenticated with check(auth.uid()=user_id or public.jmg_is_staff());

-- ---------- Storage ----------
insert into storage.buckets(id,name,public,file_size_limit)
values ('jmg-source','jmg-source',false,52428800)
on conflict (id) do update set public=false, file_size_limit=52428800;

insert into storage.buckets(id,name,public,file_size_limit)
values ('jmg-media','jmg-media',true,20971520)
on conflict (id) do update set public=true, file_size_limit=20971520;

-- source: solo JMG/editores del sitio. Primer directorio = site_id.
create policy "source read" on storage.objects for select to authenticated
using(bucket_id='jmg-source' and exists(select 1 from public.jmg_sites s where s.id::text=(storage.foldername(name))[1] and public.jmg_can_access_site(s.id)));
create policy "source insert" on storage.objects for insert to authenticated
with check(bucket_id='jmg-source' and exists(select 1 from public.jmg_sites s where s.id::text=(storage.foldername(name))[1] and public.jmg_can_manage_site(s.id)));
create policy "source update" on storage.objects for update to authenticated
using(bucket_id='jmg-source' and exists(select 1 from public.jmg_sites s where s.id::text=(storage.foldername(name))[1] and public.jmg_can_manage_site(s.id)));
create policy "source delete" on storage.objects for delete to authenticated
using(bucket_id='jmg-source' and exists(select 1 from public.jmg_sites s where s.id::text=(storage.foldername(name))[1] and public.jmg_can_manage_site(s.id)));

-- media: lectura pública; escritura solo usuarios con acceso al site.
create policy "media insert" on storage.objects for insert to authenticated
with check(bucket_id='jmg-media' and exists(select 1 from public.jmg_sites s where s.id::text=(storage.foldername(name))[1] and public.jmg_can_access_site(s.id)));
create policy "media update" on storage.objects for update to authenticated
using(bucket_id='jmg-media' and exists(select 1 from public.jmg_sites s where s.id::text=(storage.foldername(name))[1] and public.jmg_can_access_site(s.id)));
create policy "media delete" on storage.objects for delete to authenticated
using(bucket_id='jmg-media' and exists(select 1 from public.jmg_sites s where s.id::text=(storage.foldername(name))[1] and public.jmg_can_access_site(s.id)));

-- ---------- Índices ----------
create index if not exists idx_jmg_sites_org on public.jmg_sites(organization_id);
create index if not exists idx_jmg_fields_site_page on public.jmg_fields(site_id,page_path,sort_order);
create index if not exists idx_jmg_content_site on public.jmg_content(site_id);
create index if not exists idx_jmg_files_site on public.jmg_files(site_id);
create index if not exists idx_jmg_deploys_site_created on public.jmg_deploys(site_id,created_at desc);

-- ============================================================
-- DESPUÉS DE CREAR TU PRIMER USUARIO EN Authentication > Users:
-- Sustituye UUID_AQUI por su UUID y ejecuta:
-- update public.jmg_profiles set system_role='superadmin' where user_id='UUID_AQUI';
-- ============================================================
