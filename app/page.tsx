import {redirect} from 'next/navigation';
import {access} from '@/lib/supabase';
import Desk from '@/components/desk';
export const dynamic='force-dynamic';
export default async function Page(){const {db,user}=await access();if(!user)redirect('/login');const {data,error}=await db.rpc('writingdesk_load');return <Desk initial={data} initialError={error?.message} email={user.email||''}/>;}
