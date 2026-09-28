import { createClient } from '@supabase/supabase-js';

export function adminDb(){
 const url=process.env.SUPABASE_URL; const key=process.env.SUPABASE_SERVICE_ROLE_KEY;
 if(!url||!key)throw new Error('Faltan SUPABASE_URL o SUPABASE_SERVICE_ROLE_KEY en variables de entorno');
 return createClient(url,key,{auth:{persistSession:false,autoRefreshToken:false}});
}
export function json(statusCode,body){return{statusCode,headers:{'content-type':'application/json; charset=utf-8','cache-control':'no-store'},body:JSON.stringify(body)}}
export async function authContext(event){
 const token=(event.headers.authorization||event.headers.Authorization||'').replace(/^Bearer\s+/i,''); if(!token)throw new Error('No autorizado');
 const db=adminDb(); const {data:{user},error}=await db.auth.getUser(token); if(error||!user)throw new Error('Sesión no válida');
 const {data:profile}=await db.from('jmg_profiles').select('*').eq('user_id',user.id).maybeSingle(); if(!profile)throw new Error('Perfil no encontrado');
 return{db,user,profile};
}
export async function siteAccess(ctx,siteId,{manage=false}={}){
 const {db,user,profile}=ctx; const {data:site,error}=await db.from('jmg_sites').select('*,jmg_organizations(name)').eq('id',siteId).maybeSingle(); if(error||!site)throw new Error('Web no encontrada');
 if(['superadmin','staff'].includes(profile.system_role))return site;
 const {data:m}=await db.from('jmg_memberships').select('role').eq('organization_id',site.organization_id).eq('user_id',user.id).maybeSingle(); if(!m)throw new Error('No tienes acceso a esta web'); if(manage&&!['owner','editor'].includes(m.role))throw new Error('No tienes permisos para esta acción'); return site;
}
