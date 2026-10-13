export const publications = [
  {key:'substack-david',name:'David McLemore · Substack',url:'https://davidmclemore.substack.com'},
  {key:'substack-reading',name:'Things Worth Reading · Substack',url:'https://thingsworthreading.substack.com'},
];
export const isSubstack = key => publications.some(p=>p.key===key);
