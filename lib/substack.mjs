import {XMLParser, XMLValidator} from 'fast-xml-parser';
import {plain} from './domain.mjs';

import {publications} from './publications.mjs';
export {publications,isSubstack} from './publications.mjs';
const scalar = value => typeof value==='string'?value:'';
export function parseFeed(xml,publication){
  if(xml.length>2000000 || /<!DOCTYPE|<!ENTITY/i.test(xml) || XMLValidator.validate(xml)!==true)throw new Error('Substack returned an invalid or oversized RSS feed');
  const parsed=new XMLParser({ignoreAttributes:true,parseTagValue:false,trimValues:true}).parse(xml);
  const channel=parsed.rss?.channel;
  if(!channel || typeof channel!=='object')throw new Error('Substack did not return an RSS feed');
  const entries=channel.item===undefined?[]:Array.isArray(channel.item)?channel.item:[channel.item];
  const items=new Map();
  for(const entry of entries){
    let url;
    try{url=new URL(scalar(entry.link));}catch{throw new Error('Substack post has an invalid link');}
    if(url.origin!==publication.url || !url.pathname.startsWith('/p/'))throw new Error('Substack post links must belong to this publication');
    url.search='';url.hash='';
    const date=Date.parse(scalar(entry.pubDate));
    if(!Number.isFinite(date))throw new Error('Substack post has an invalid publication date');
    const publishedAt=new Date(date).toISOString();
    const item={id:scalar(entry.guid)||url.href,title:plain(scalar(entry.title)).slice(0,300)||'Untitled post',url:url.href,status:'published',stage:'finished',format:'Newsletter',summary:plain(scalar(entry.description)).slice(0,500),publishedAt,modified:publishedAt,destination:publication.name};
    items.set(item.id,item);
  }
  return [...items.values()];
}

// RSS is a rolling window, not a complete scan or evidence of deletion.
export function retainFeedHistory(current,previous){
  const items=new Map(previous.map(d=>[d.source_id,d.snapshot]));
  for(const item of current)items.set(item.id,item);
  return [...items.values()];
}

export async function fetchPublication(key,fetcher=fetch){
  const publication=publications.find(p=>p.key===key);
  if(!publication)throw new Error('Unknown Substack publication');
  const response=await fetcher(publication.url+'/feed',{redirect:'error',signal:AbortSignal.timeout(15000),cache:'no-store',headers:{Accept:'application/rss+xml, application/xml, text/xml'}});
  if(!response.ok)throw new Error(`Substack feed unavailable (${response.status}). Try again later.`);
  if(Number(response.headers.get('content-length'))>2000000)throw new Error('Substack feed is too large');
  if(!response.body)throw new Error('Substack returned an empty response');
  const reader=response.body.getReader();const chunks=[];let size=0;
  try{while(true){const {done,value}=await reader.read();if(done)break;size+=value.byteLength;if(size>2000000)throw new Error('Substack feed is too large');chunks.push(value);}}finally{await reader.cancel();}
  const bytes=new Uint8Array(size);let offset=0;for(const chunk of chunks){bytes.set(chunk,offset);offset+=chunk.byteLength;}
  return parseFeed(new TextDecoder().decode(bytes),publication);
}
