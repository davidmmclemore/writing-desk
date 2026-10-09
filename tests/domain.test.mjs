import test from 'node:test';
import assert from 'node:assert/strict';
import {safeUrl,dateKey,plannedEvents,mapSource,importBook} from '../lib/domain.mjs';
test('external source URLs reject active protocols',()=>{assert.equal(safeUrl('javascript:alert(1)'), '');assert.equal(safeUrl('https://example.org/work'),'https://example.org/work');});
test('calendar dates respect Chicago midnight',()=>{assert.equal(dateKey(new Date('2026-10-09T03:00:00Z'),'America/Chicago'),'2026-10-08');assert.equal(dateKey(new Date('2026-10-09T06:00:00Z'),'America/Chicago'),'2026-10-09');});
test('ready writing stays open; publication is separate',()=>{const p=mapSource('piece',{id:'abc',title:'Essay',status:'ready',stage:'editing'},'https://example.org');assert.equal(p.status,'ready');assert.equal(p.url,'https://example.org/the-piece/assignments/abc');assert.equal(mapSource('piece',{id:'abc',status:'published'},'https://example.org').status,'finished');});
test('calendar preserves date-only planning and omits archives',()=>{const events=plannedEvents([{id:'a',data:{title:'Work',draftDate:'2026-10-09',publishDate:'2026-10-12'}},{id:'b',data:{title:'Archive',archived:true,publishDate:'2026-10-09'}}]);assert.deepEqual(events.map(e=>[e.label,e.date]),[['Draft due','2026-10-09'],['Publication plan','2026-10-12']]);});
test('saved paragraphs are not classified as unfinished',()=>{assert.equal(mapSource('paragraphs',{id:'p',title:'Saved',body:'<p>A thought</p>'},'https://example.org').status,'saved');});
test('Book metadata excludes manuscript content',()=>{const r=importBook({title:'Book',chapters:[{id:'c',title:'Chapter',status:'final',content:'Private manuscript'}]});assert.equal(r.stage,'finished');assert.equal(r.chapters[0].content,undefined);assert.throws(()=>importBook({title:'Bad'}));});
