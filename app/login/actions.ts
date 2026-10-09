'use server';
import {redirect} from 'next/navigation';
import {client,access} from '@/lib/supabase';
export async function signIn(form:FormData){const db=await client();const email=String(form.get('email')||'').trim(),password=String(form.get('password')||'');const {error}=await db.auth.signInWithPassword({email,password});if(error)redirect('/login?error=1');const {user}=await access();if(!user){await db.auth.signOut();redirect('/login?error=1');}redirect('/');}
export async function signOut(){const db=await client();await db.auth.signOut({scope:'local'});redirect('/login');}
