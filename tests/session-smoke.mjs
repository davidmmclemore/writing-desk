// Optional authenticated runtime check using an explicitly provisioned throwaway account.
// Supply QA_ACCOUNT_FILE pointing to {email,password}; credentials and tokens are never logged.
import {readFile} from 'node:fs/promises';
import {spawn} from 'node:child_process';
import assert from 'node:assert/strict';
import {createServerClient} from '@supabase/ssr';
import {supabaseUrl,supabaseKey} from '../lib/config.ts';
const account=JSON.parse(await readFile(process.env.QA_ACCOUNT_FILE,'utf8'));
const jar=new Map();
const db=createServerClient(supabaseUrl,supabaseKey,{cookieOptions:{name:'writingdesk-session'},cookies:{getAll:()=>Array.from(jar,([name,value])=>({name,value})),setAll:values=>values.forEach(v=>jar.set(v.name,v.value))}});
const {error}=await db.auth.signInWithPassword({email:account.email,password:account.password});assert.equal(error,null,'test account signs in');
const cookie=Array.from(jar,([k,v])=>k+'='+v).join('; '),origin='http://localhost:3106';
const server=spawn(process.execPath,['node_modules/next/dist/bin/next','start','--hostname','127.0.0.1','--port','3106'],{stdio:'ignore'});
async function api(path,body){const r=await fetch('http://127.0.0.1:3106'+path,{method:body?'POST':'GET',headers:{Cookie:cookie,Origin:origin,'Content-Type':'application/json'},body:body?JSON.stringify(body):undefined,redirect:'manual'});return {status:r.status,body:await r.json()};}
try{let ready=false;for(let i=0;i<40;i++){try{if((await fetch('http://127.0.0.1:3106/login')).ok){ready=true;break;}}catch{}await new Promise(r=>setTimeout(r,250));}assert.ok(ready);console.log('Local server ready');let result=await api('/api/desk');assert.equal(result.status,200,JSON.stringify(result.body));assert.equal(result.body.projects.length,0);
console.log('Private load passed');const created=await api('/api/desk',{operation:'project',payload:{data:{title:'Runtime QA piece',stage:'drafting',onDesk:true,nextAction:'Draft opening',draftDate:'2026-10-12',publishDate:'2026-10-16'}}});assert.equal(created.status,200,JSON.stringify(created.body));const id=created.body.id;
console.log('Project create passed');const updated=await api('/api/desk',{operation:'project',payload:{id,version:1,data:{...created.body.data,commitment:true}}});assert.equal(updated.status,200);assert.equal(updated.body.version,2);
const stale=await api('/api/desk',{operation:'project',payload:{id,version:1,data:created.body.data}});assert.equal(stale.status,409);
for(const source of ['piece','paragraph-drafts','paragraphs','ideas','bible-margins','study']){console.log('Checking source '+source);const synced=await api('/api/discover',{source});assert.equal(synced.status,200,source+': '+JSON.stringify(synced.body));}
const html=await fetch('http://127.0.0.1:3106/',{headers:{Cookie:cookie}});assert.equal(html.status,200);const content=await html.text();assert.ok(content.includes('Runtime QA piece'));assert.ok(content.includes('Draft opening'));
const exportResult=await fetch('http://127.0.0.1:3106/api/export',{headers:{Cookie:cookie}});assert.equal(exportResult.status,200);assert.equal((await exportResult.json()).projects.length,1);
assert.equal((await api('/api/desk',{operation:'delete_project',payload:{id,version:2}})).status,200);
console.log('Authenticated runtime check passed: password sign-in, membership, project create/update, stale rejection, all six live source readers, rendered project, export, delete.');}finally{server.kill();await db.auth.signOut({scope:'local'});}
