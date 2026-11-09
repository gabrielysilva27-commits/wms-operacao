import {config} from './config.js';
export const configured=Boolean(config.supabaseUrl&&config.publishableKey);
let session=null,refreshing=null;
export async function request(path,{method='GET',body,token=session?.access_token,headers={}}={}){
 if(!configured)throw new Error('Banco exclusivo ainda não conectado');
 if(session&&session.expires_at*1000<Date.now()+30000&&!path.startsWith('/auth/')){
 if(!refreshing)refreshing=(async()=>{const refresh=await fetch(config.supabaseUrl+'/auth/v1/token?grant_type=refresh_token',{method:'POST',headers:{apikey:config.publishableKey,'Content-Type':'application/json'},body:JSON.stringify({refresh_token:session.refresh_token})});
 if(!refresh.ok){session=null;throw new Error('Sessão expirada. Entre novamente.');}session=await refresh.json();})();
 try{await refreshing;token=session.access_token;}finally{refreshing=null;}
 }
 const r=await fetch(config.supabaseUrl+path,{method,headers:{apikey:config.publishableKey,...(token?{Authorization:`Bearer ${token}`} :{}),'Content-Type':'application/json',...headers},body:body===undefined?undefined:JSON.stringify(body)});
 if(!r.ok){const e=await r.json().catch(()=>({}));throw new Error(path.startsWith('/auth/v1/token')?'Usuário ou senha inválidos.':e.message||e.msg||'Falha na conexão com o WMS');}return r.status===204?null:r.json();
}
export async function login(username,password){const normalized=username.trim().toLowerCase();const email=normalized.includes('@')?normalized:normalized+'@users.wms.invalid';session=await request('/auth/v1/token?grant_type=password',{method:'POST',body:{email,password},token:null});return session.user;}
export async function logout(){if(session)await request('/auth/v1/logout',{method:'POST'});session=null;}
export const currentUser=()=>session?.user;
export const rpc=(name,body)=>request('/rest/v1/rpc/'+name,{method:'POST',body});
export const rows=(name,w)=>request('/rest/v1/'+name+'?warehouse_id=eq.'+encodeURIComponent(w)+'&order=created_at.desc&limit=200');
export async function memberships(){return request('/rest/v1/memberships?active=eq.true');}
export async function uploadObject(path,file){const r=await fetch(config.supabaseUrl+'/storage/v1/object/wms-evidence/'+path,{method:'POST',headers:{apikey:config.publishableKey,Authorization:`Bearer ${session.access_token}`,'Content-Type':file.type,'x-upsert':'false'},body:file});if(!r.ok&&r.status!==409)throw new Error('Falha no envio do arquivo');}
