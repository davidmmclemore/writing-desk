import type {Metadata,Viewport} from 'next';
import './globals.css';
export const metadata:Metadata={title:'The Writing Desk · Gathered Pages',description:'A place for everything you hope to write, and a clear next step for what you are writing now.',manifest:'/manifest.webmanifest',icons:{icon:'/icons/icon-192.png',apple:'/icons/apple-touch-icon.png'},robots:{index:false,follow:false},appleWebApp:{capable:true,title:'Writing Desk',statusBarStyle:'default'}};
export const viewport:Viewport={width:'device-width',initialScale:1,themeColor:'#f4f1e9'};
export default function Layout({children}:{children:React.ReactNode}){return <html lang="en"><body>{children}</body></html>;}
