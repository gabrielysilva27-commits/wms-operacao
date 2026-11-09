// Binary files stay in IndexedDB, never in load/list responses or localStorage.
import {rpc,uploadObject,currentUser} from './api.js';
let running=false;
function db(){return new Promise((resolve,reject)=>{const r=indexedDB.open('wms-media-v1',1);r.onupgradeneeded=()=>r.result.createObjectStore('uploads',{keyPath:'id'});r.onsuccess=()=>resolve(r.result);r.onerror=()=>reject(r.error);});}
async function store(mode,action){const d=await db();return new Promise((resolve,reject)=>{const t=d.transaction('uploads',mode),r=action(t.objectStore('uploads'));t.oncomplete=()=>{d.close();resolve(r.result);};t.onerror=()=>{d.close();reject(t.error);};});}
export const pendingMedia=()=>store('readonly',s=>s.getAll());
export async function queueMedia({file,warehouseId,palletId,loadId,demo}){
 if(!['image/jpeg','image/png','image/webp','video/mp4'].includes(file.type)||file.size>52428800)throw new Error('Use JPG, PNG, WebP ou MP4 de até 50 MB');
 const entry={id:crypto.randomUUID(),file,warehouseId,palletId,loadId,demo,owner:currentUser()?.id,attempts:0,nextAt:0,state:'pending'};
 await store('readwrite',s=>s.put(entry));return entry.id;
}
export async function flushMedia(){if(running||!navigator.onLine)return;running=true;try{for(const e of await pendingMedia()){
 if(e.demo||e.owner!==currentUser()?.id||e.attempts>=5||Date.now()<e.nextAt)continue;
 try{if(!e.remote){e.remote=await rpc('reserve_media',{w:e.warehouseId,p:e.palletId||null,l:e.loadId||null,mime:e.file.type,bytes:e.file.size,caption:e.file.name});if(Array.isArray(e.remote))e.remote=e.remote[0];await store('readwrite',s=>s.put(e));}
 await uploadObject(e.remote.object_path,e.file);await rpc('finalize_media',{w:e.warehouseId,m:e.remote.id});await store('readwrite',s=>s.delete(e.id));
 }catch(err){e.attempts++;e.state='failed';e.nextAt=Date.now()+Math.min(3600000,15000*2**e.attempts);e.error=err.message;await store('readwrite',s=>s.put(e));}
 }}finally{running=false;}}
export async function retryMedia(id){const entries=await pendingMedia();const e=entries.find(x=>x.id===id);if(!e) return;e.attempts=0;e.nextAt=0;await store('readwrite',s=>s.put(e));await flushMedia();}
