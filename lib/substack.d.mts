export const publications: {key:string;name:string;url:string}[];
export function isSubstack(key:string):boolean;
export function parseFeed(xml:string,publication:{key:string;name:string;url:string}):Record<string,string>[];
export function retainFeedHistory(current:Record<string,string>[],previous:{source_id:string;snapshot:Record<string,string>}[]):Record<string,string>[];
export function fetchPublication(key:string,fetcher?:typeof fetch):Promise<Record<string,string>[]>;
