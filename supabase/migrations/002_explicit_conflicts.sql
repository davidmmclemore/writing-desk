create or replace function public.writingdesk_mutate(operation text, payload jsonb) returns jsonb language plpgsql security invoker set search_path='' as $$
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
  if result is null then raise exception 'Changed in another tab. Reload before saving.' using errcode='PT409'; end if;
 end if;
elsif operation='delete_project' then delete from writingdesk.projects where id=(payload->>'id')::uuid and version=(payload->>'version')::int; get diagnostics count_changed=row_count; if count_changed<>1 then raise exception 'Changed in another tab. Reload before deleting.' using errcode='PT409'; end if;
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
