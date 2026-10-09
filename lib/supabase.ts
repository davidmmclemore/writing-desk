import 'server-only';
import {createServerClient} from '@supabase/ssr';
import {cookies} from 'next/headers';
import {supabaseUrl,supabaseKey} from './config';
export async function client(){const jar=await cookies();return createServerClient(supabaseUrl,supabaseKey,{cookieOptions:{name:'writingdesk-session',sameSite:'lax',secure:process.env.NODE_ENV==='production',httpOnly:true,path:'/'},cookies:{getAll:()=>jar.getAll(),setAll:values=>{try{values.forEach(({name,value,options})=>jar.set(name,value,options));}catch{ /* Server components cannot write cookies; proxy refreshes. */}}}});}
export async function access(){const db=await client();const {data:{user},error}=await db.auth.getUser();if(error||!user||user.is_anonymous||!user.email_confirmed_at)return {db,user:null};const {data:m,error:e}=await db.from('gathered_pages_members').select('revoked_at,approved_at').eq('user_id',user.id).maybeSingle();return {db,user:!e&&m?.approved_at&&!m.revoked_at?user:null};}
