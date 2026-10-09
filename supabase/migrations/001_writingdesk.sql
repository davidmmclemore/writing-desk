begin;
create schema if not exists writingdesk;
revoke all on schema writingdesk from public, anon;
grant usage on schema writingdesk to authenticated;
create function writingdesk.allowed() returns boolean language sql stable security invoker set search_path='' as $$
 select auth.uid() is not null and not coalesce((auth.jwt()->>'is_anonymous')::boolean,false) and exists(select 1 from public.gathered_pages_members where user_id=auth.uid() and revoked_at is null and approved_at is not null);
$$;
create table writingdesk.projects(id uuid primary key default gen_random_uuid(),user_id uuid not null default auth.uid() references auth.users(id) on delete cascade, data jsonb not null default '{}'::jsonb,version integer not null default 1,created_at timestamptz not null default now(),updated_at timestamptz not null default now(),unique(id,user_id), check(jsonb_typeof(data)='object'),check(length(data->>'title') between 1 and 300),check(data->>'stage' in ('idea','research','outline','drafting','revising','ready','finished')));
create table writingdesk.series(id uuid primary key default gen_random_uuid(),user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,data jsonb not null,version integer not null default 1,updated_at timestamptz not null default now(),unique(id,user_id),check(length(data->>'title') between 1 and 300));
create table writingdesk.tasks(id uuid primary key default gen_random_uuid(),user_id uuid not null default auth.uid(),project_id uuid not null,data jsonb not null,version integer not null default 1,updated_at timestamptz not null default now(),foreign key(project_id,user_id) references writingdesk.projects(id,user_id) on delete cascade,check(length(data->>'title') between 1 and 300));
create table writingdesk.links(id uuid primary key default gen_random_uuid(),user_id uuid not null default auth.uid(),project_id uuid not null,source text not null,source_id text not null,relationship text not null,title text not null,url text not null default '',snapshot jsonb not null default '{}',updated_at timestamptz not null default now(),foreign key(project_id,user_id) references writingdesk.projects(id,user_id) on delete cascade,unique(user_id,source,source_id));
create table writingdesk.discoveries(id uuid primary key default gen_random_uuid(),user_id uuid not null default auth.uid(),source text not null,source_id text not null,title text not null,url text not null default '',status text not null default 'open',decision text not null default 'new' check(decision in ('new','later','dismissed','accepted')),snapshot jsonb not null default '{}',updated_at timestamptz not null default now(),unique(user_id,source,source_id));
create table writingdesk.sync_runs(id uuid primary key default gen_random_uuid(),user_id uuid not null default auth.uid(),source text not null,success boolean not null,message text not null default '',created_at timestamptz not null default now());
create table writingdesk.reviews(id uuid primary key default gen_random_uuid(),user_id uuid not null default auth.uid(),data jsonb not null,created_at timestamptz not null default now());
create table writingdesk.preferences(user_id uuid primary key default auth.uid(),data jsonb not null default '{}',version integer not null default 1,updated_at timestamptz not null default now());
do $$ declare t text; begin foreach t in array array['projects','series','tasks','links','discoveries','sync_runs','reviews','preferences'] loop execute format('alter table writingdesk.%I enable row level security',t); execute format('create policy owner_access on writingdesk.%I for all to authenticated using(user_id=(select auth.uid()) and (select writingdesk.allowed())) with check(user_id=(select auth.uid()) and (select writingdesk.allowed()))',t); execute format('grant select,insert,update,delete on writingdesk.%I to authenticated',t); execute format('create index on writingdesk.%I(user_id)',t); end loop; end $$;
-- Thin invoker transport in the already-exposed public schema avoids changing shared Data API settings.
create function public.writingdesk_load() returns jsonb language plpgsql security invoker set search_path='' as $$ begin
if not writingdesk.allowed() then raise exception 'Approved membership required' using errcode='42501'; end if;
return jsonb_build_object('projects',(select coalesce(jsonb_agg(to_jsonb(p) order by p.updated_at desc),'[]') from writingdesk.projects p),'series',(select coalesce(jsonb_agg(to_jsonb(s)),'[]') from writingdesk.series s),'tasks',(select coalesce(jsonb_agg(to_jsonb(t)),'[]') from writingdesk.tasks t),'links',(select coalesce(jsonb_agg(to_jsonb(l)),'[]') from writingdesk.links l),'discoveries',(select coalesce(jsonb_agg(to_jsonb(d) order by d.updated_at desc),'[]') from writingdesk.discoveries d),'runs',(select coalesce(jsonb_agg(to_jsonb(r)),'[]') from (select * from writingdesk.sync_runs order by created_at desc limit 50) r),'reviews',(select coalesce(jsonb_agg(to_jsonb(r)),'[]') from (select * from writingdesk.reviews order by created_at desc limit 12) r),'preferences',(select coalesce(data,'{}') from writingdesk.preferences where user_id=auth.uid())); end $$;
create function public.writingdesk_mutate(operation text, payload jsonb) returns jsonb language plpgsql security invoker set search_path='' as $$
declare result jsonb; pid uuid; did uuid; item record; existing uuid; count_changed int; tbl text; begin
if not writingdesk.allowed() then raise exception 'Approved membership required' using errcode='42501'; end if;
if octet_length(payload::text)>250000 then raise exception 'Payload too large'; end if;
if operation in ('project','series','task') then
 tbl:=case operation when 'project' then 'projects' when 'series' then 'series' else 'tasks' end;
 if payload->>'id' is null then
  if operation='task' then insert into writingdesk.tasks(project_id,data) values((payload->>'project_id')::uuid,payload->'data') returning to_jsonb(tasks.*) into result;
  else execute format('insert into writingdesk.%I(data) values($1) returning to_jsonb(%I.*)',tbl,tbl) into result using payload->'data'; end if;
 else
  execute format('update writingdesk.%I set data=$1, version=version+1,updated_at=now() where id=$2 and version=$3 returning to_jsonb(%I.*)',tbl,tbl) into result using payload->'data',(payload->>'id')::uuid,(payload->>'version')::int;
  if result is null then raise exception 'Changed in another tab. Reload before saving.' using errcode='40001'; end if;
 end if;
elsif operation='delete_project' then delete from writingdesk.projects where id=(payload->>'id')::uuid and version=(payload->>'version')::int; get diagnostics count_changed=row_count; if count_changed<>1 then raise exception 'Changed in another tab. Reload before deleting.'; end if;
elsif operation='delete_task' then delete from writingdesk.tasks where id=(payload->>'id')::uuid;
elsif operation='unlink' then delete from writingdesk.links where id=(payload->>'id')::uuid;
elsif operation='decision' then update writingdesk.discoveries set decision=payload->>'decision' where id=(payload->>'id')::uuid;
elsif operation='attach' then
 pid:=(payload->>'project_id')::uuid; did:=(payload->>'discovery_id')::uuid;
 select * into item from writingdesk.discoveries where id=did for update;
 if not found then raise exception 'Source item unavailable'; end if;
 if pid is null then insert into writingdesk.projects(data) values(jsonb_build_object('title',item.title,'stage',coalesce(payload->>'stage','idea'),'nextAction',coalesce(payload->>'nextAction',''),'onDesk',true,'commitment',false,'format',coalesce(item.snapshot->>'format','Essay'),'description',coalesce(item.snapshot->>'summary',''))) returning id into pid; end if;
 insert into writingdesk.links(project_id,source,source_id,relationship,title,url,snapshot) values(pid,item.source,item.source_id,coalesce(payload->>'relationship','Primary draft'),item.title,item.url,item.snapshot) on conflict(user_id,source,source_id) do nothing;
 select project_id into existing from writingdesk.links where user_id=auth.uid() and source=item.source and source_id=item.source_id;
 if existing<>pid then raise exception 'This source is already attached to another project'; end if;
 update writingdesk.discoveries set decision='accepted' where id=did;
 result:=jsonb_build_object('id',pid);
elsif operation='link' then
 insert into writingdesk.links(project_id,source,source_id,relationship,title,url,snapshot) values((payload->>'project_id')::uuid,payload->>'source',payload->>'source_id',payload->>'relationship',payload->>'title',coalesce(payload->>'url',''),coalesce(payload->'snapshot','{}')) returning to_jsonb(links.*) into result;
elsif operation='review' then insert into writingdesk.reviews(data) values(payload->'data') returning to_jsonb(reviews.*) into result;
elsif operation='preferences' then insert into writingdesk.preferences(data) values(payload->'data') on conflict(user_id) do update set data=excluded.data,version=writingdesk.preferences.version+1,updated_at=now();
else raise exception 'Unknown operation'; end if;
return coalesce(result,'{}'); end $$;
create function public.writingdesk_candidates(source_key text) returns jsonb language plpgsql security invoker set search_path='' as $$
declare records jsonb; begin
if not writingdesk.allowed() then raise exception 'Approved membership required' using errcode='42501'; end if;
case source_key
when 'piece' then select coalesce(jsonb_agg(to_jsonb(a)),'[]') into records from piece.assignments a where not is_archived and (user_id=auth.uid() or owner_id=auth.uid());
when 'paragraph-drafts' then select coalesce(jsonb_agg(to_jsonb(a)),'[]') into records from onegreatparagraph.drafts a where user_id=auth.uid() and length(trim(body))>0;
when 'paragraphs' then select coalesce(jsonb_agg(to_jsonb(a)),'[]') into records from onegreatparagraph.paragraphs a where user_id=auth.uid() and not is_archived;
when 'ideas' then select coalesce(jsonb_agg(to_jsonb(a)),'[]') into records from ideagarden.ideas a where user_id=auth.uid() and not archived;
when 'bible-margins' then select coalesce(jsonb_agg(to_jsonb(a)),'[]') into records from bible_margins.items a where user_id=auth.uid() and archived_at is null;
when 'study' then select coalesce(jsonb_agg(to_jsonb(a)),'[]') into records from thestudy.studies a where user_id=auth.uid() and archived_at is null;
else raise exception 'Source requires manual linking'; end case;
return records; end $$;
create function public.writingdesk_sync(source_key text,items jsonb,success boolean default true,message text default '') returns void language plpgsql security invoker set search_path='' as $$
declare item jsonb; begin
if not writingdesk.allowed() then raise exception 'Approved membership required' using errcode='42501'; end if;
if jsonb_array_length(items)>10000 or octet_length(items::text)>5000000 then raise exception 'Import too large'; end if;
if success then
 for item in select value from jsonb_array_elements(items) loop
  insert into writingdesk.discoveries(source,source_id,title,url,status,snapshot) values(source_key,item->>'id',left(item->>'title',300),coalesce(item->>'url',''),coalesce(item->>'status','open'),item)
  on conflict(user_id,source,source_id) do update set title=excluded.title,url=excluded.url,status=excluded.status,snapshot=excluded.snapshot,updated_at=now();
  update writingdesk.links set snapshot=item,title=left(item->>'title',300),url=coalesce(item->>'url',''),updated_at=now() where user_id=auth.uid() and source=source_key and source_id=item->>'id';
 end loop;
 -- Missing source records are marked for review, never deleted or declared finished.
 update writingdesk.discoveries set status='unavailable' where user_id=auth.uid() and source=source_key and source_id not in(select value->>'id' from jsonb_array_elements(items));
 update writingdesk.links set snapshot=jsonb_set(snapshot,'{status}','"unavailable"') where user_id=auth.uid() and source=source_key and source_id not in(select value->>'id' from jsonb_array_elements(items));
end if;
insert into writingdesk.sync_runs(source,success,message) values(source_key,success,left(message,1000));
end $$;
revoke all on function public.writingdesk_load() from public,anon;
revoke all on function public.writingdesk_mutate(text,jsonb) from public,anon;
revoke all on function public.writingdesk_candidates(text) from public,anon;
revoke all on function public.writingdesk_sync(text,jsonb,boolean,text) from public,anon;
grant execute on function public.writingdesk_load(),public.writingdesk_mutate(text,jsonb),public.writingdesk_candidates(text),public.writingdesk_sync(text,jsonb,boolean,text) to authenticated;
revoke all on function writingdesk.allowed() from public,anon;
grant execute on function writingdesk.allowed() to authenticated;
commit;
