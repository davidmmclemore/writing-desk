import type {Project,ProjectData,Snapshot} from './model';
export function safeUrl(value:unknown):string;
export function plain(value:unknown):string;
export function dateKey(date?:Date,zone?:string):string;
export function openProject(p:ProjectData):boolean;
export function plannedEvents(projects:Project[]):{id:string;key:string;title:string;date:string;label:string}[];
export function mapSource(source:string,r:Record<string,unknown>,base:string):Snapshot;
export function importBook(raw:unknown):ProjectData&{chapters:{id:string;title:string;status:string}[]};
