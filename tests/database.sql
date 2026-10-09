begin;
insert into auth.users(id,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data) values
 ('00000000-0000-4000-8000-000000000a01','writingdesk-test-a@example.invalid','',now(),'{"provider":"email","providers":["email"]}','{}'),
 ('00000000-0000-4000-8000-000000000b01','writingdesk-test-b@example.invalid','',now(),'{"provider":"email","providers":["email"]}','{}');
insert into public.gathered_pages_members(user_id,role,approved_at) values('00000000-0000-4000-8000-000000000a01','member',now()),('00000000-0000-4000-8000-000000000b01','member',now());
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-000000000a01","role":"authenticated","is_anonymous":false}',true);
do $$ declare p jsonb; pid uuid; did uuid; n integer; blocked boolean:=false; begin
p:=public.writingdesk_mutate('project','{"data":{"title":"Test project","stage":"drafting","onDesk":true,"nextAction":"My planning choice"}}');pid:=(p->>'id')::uuid;
perform public.writingdesk_mutate('task',jsonb_build_object('project_id',pid,'data',jsonb_build_object('title','Task','done',false)));
perform public.writingdesk_sync('test','[{"id":"source-1","title":"Test source","status":"open"}]');
select id into did from writingdesk.discoveries where source='test';
perform public.writingdesk_mutate('decision',jsonb_build_object('id',did,'decision','dismissed'));
perform public.writingdesk_sync('test','[{"id":"source-1","title":"Updated source","status":"ready"}]');
select count(*) into n from writingdesk.discoveries where source='test';if n<>1 then raise exception 'Duplicate discovery';end if;
if (select decision from writingdesk.discoveries where id=did)<>'dismissed' then raise exception 'Dismissal overwritten';end if;
perform public.writingdesk_mutate('attach',jsonb_build_object('project_id',pid,'discovery_id',did,'relationship','Primary draft'));
perform public.writingdesk_mutate('attach',jsonb_build_object('project_id',pid,'discovery_id',did,'relationship','Primary draft'));
if (select count(*) from writingdesk.links)<>1 then raise exception 'Duplicate link';end if;
perform public.writingdesk_sync('test','[]',false,'Provider failed');
if (select status from writingdesk.discoveries where id=did)<>'ready' then raise exception 'Failure erased source state';end if;
perform public.writingdesk_sync('test','[]');
if (select status from writingdesk.discoveries where id=did)<>'unavailable' then raise exception 'Missing source not surfaced';end if;
if (select data->>'nextAction' from writingdesk.projects where id=pid)<>'My planning choice' then raise exception 'Planning overwritten';end if;
perform public.writingdesk_mutate('project',jsonb_build_object('id',pid,'version',1,'data',p->'data'));
begin perform public.writingdesk_mutate('project',jsonb_build_object('id',pid,'version',1,'data',p->'data')); exception when sqlstate 'PT409' then blocked:=true;end;
if not blocked then raise exception 'Stale save accepted';end if;
perform public.writingdesk_candidates('piece');perform public.writingdesk_candidates('paragraph-drafts');perform public.writingdesk_candidates('paragraphs');perform public.writingdesk_candidates('ideas');perform public.writingdesk_candidates('bible-margins');perform public.writingdesk_candidates('study');
end $$;
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-000000000b01","role":"authenticated","is_anonymous":false}',true);
do $$ declare blocked boolean:=false;begin
if jsonb_array_length(public.writingdesk_load()->'projects')<>0 then raise exception 'Cross-user project leak';end if;
begin perform public.writingdesk_mutate('task','{"project_id":"00000000-0000-4000-8000-000000009999","data":{"title":"Bad relationship"}}');exception when foreign_key_violation then blocked:=true;end;
if not blocked then raise exception 'Invalid relationship accepted';end if;
end $$;
reset role;
update public.gathered_pages_members set revoked_at=now() where user_id='00000000-0000-4000-8000-000000000b01';
set local role authenticated;
do $$ declare blocked boolean:=false;begin begin perform public.writingdesk_load();exception when insufficient_privilege then blocked:=true;end;if not blocked then raise exception 'Revoked membership allowed';end if;end $$;
reset role;
do $$ begin if has_function_privilege('anon','public.writingdesk_load()','execute') then raise exception 'Anon transport exposed';end if;end $$;
rollback;
select 'Writing Desk database regression checks passed; all test data rolled back.' as result;
