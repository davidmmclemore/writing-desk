import {createServerClient} from '@supabase/ssr';
import {NextResponse,type NextRequest} from 'next/server';
import {supabaseUrl,supabaseKey} from './lib/config';
export async function proxy(req:NextRequest){let res=NextResponse.next({request:req});const db=createServerClient(supabaseUrl,supabaseKey,{cookieOptions:{name:'writingdesk-session',sameSite:'lax',secure:process.env.NODE_ENV==='production',httpOnly:true,path:'/'},cookies:{getAll:()=>req.cookies.getAll(),setAll:values=>{values.forEach(({name,value})=>req.cookies.set(name,value));res=NextResponse.next({request:req});values.forEach(({name,value,options})=>res.cookies.set(name,value,options));}}});await db.auth.getUser();return res;}
export const config={matcher:['/((?!_next/static|_next/image|icons/|favicon.ico|manifest.webmanifest|sw.js|offline.html).*)']};
