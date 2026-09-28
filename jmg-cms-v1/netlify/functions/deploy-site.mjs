import JSZip from 'jszip';
import * as cheerio from 'cheerio';
import { json, authContext, siteAccess, adminDb } from './_lib.mjs';

function cleanAttrs($,root){
 root.find('[data-jmg],[data-jmg-field],[data-jmg-item],[data-jmg-template]').addBack('[data-jmg]').each((_,el)=>{
  for(const a of Object.keys(el.attribs||{}))if(a.startsWith('data-jmg'))$(el).removeAttr(a);
 });
}
function setSub($,node,type,value){
 if(type==='image'){node.attr('src',value?.src||'');node.attr('alt',value?.alt||'');return}
 if(type==='link'){node.attr('href',value?.href||'#');if(value?.target)node.attr('target',value.target);else node.removeAttr('target');if(value?.text!==undefined)node.text(value.text);return}
 if(type==='richtext'||type==='html'){node.html(value??'');return}
 node.text(value??'');
}
function applyField($,el,type,value,settings={}){
 if(type==='text'){el.text(value??'');return}
 if(type==='richtext'||type==='html'){el.html(value??'');return}
 if(type==='image'){el.attr('src',value?.src||'');el.attr('alt',value?.alt||'');return}
 if(type==='link'){el.attr('href',value?.href||'#');if(value?.target)el.attr('target',value.target);else el.removeAttr('target');if(value?.text!==undefined)el.text(value.text);return}
 if(type==='number'||type==='color'){if(el.is('input'))el.attr('value',String(value??''));else el.text(String(value??''));return}
 if(type==='toggle'){if(value)el.removeAttr('hidden');else el.attr('hidden','');return}
 if(type==='repeater'){
  const items=Array.isArray(value)?value:[];const schema=settings?.schema||[];let template=el.children('[data-jmg-item]').first().clone();
  if(!template.length){const t=el.children('template[data-jmg-template]').first();if(t.length)template=$(t.html()).first()}
  el.children('[data-jmg-item]').remove();
  if(template?.length){for(const item of items){const n=template.clone();n.attr('data-jmg-item','');for(const sf of schema){const target=n.find(`[data-jmg-field="${sf.key}"]`).first();if(target.length)setSub($,target,sf.type||'text',item?.[sf.key])}const tpl=el.children('template[data-jmg-template]').first();if(tpl.length)tpl.before(n);else el.append(n)}}
 }
}
function applySeo($,page){
 if(!page)return;$('title').first().text(page.seo_title||page.title||'');
 let desc=$('meta[name="description"]');if(!desc.length){$('head').append('<meta name="description">');desc=$('meta[name="description"]')}desc.attr('content',page.seo_description||'');
 if(page.canonical_url){let c=$('link[rel="canonical"]');if(!c.length){$('head').append('<link rel="canonical">');c=$('link[rel="canonical"]')}c.attr('href',page.canonical_url)}
 if(page.og_image){let og=$('meta[property="og:image"]');if(!og.length){$('head').append('<meta property="og:image">');og=$('meta[property="og:image"]')}og.attr('content',page.og_image)}
 let robots=$('meta[name="robots"]');if(!robots.length){$('head').append('<meta name="robots">');robots=$('meta[name="robots"]')}robots.attr('content',`${page.robots_index?'index':'noindex'},${page.robots_follow?'follow':'nofollow'}`);
}
async function netlify(path,opts={}){const token=process.env.NETLIFY_AUTH_TOKEN;if(!token)throw new Error('Falta NETLIFY_AUTH_TOKEN en Netlify');const r=await fetch(`https://api.netlify.com/api/v1${path}`,{...opts,headers:{Authorization:`Bearer ${token}`,...(opts.headers||{})}});const text=await r.text();let data;try{data=JSON.parse(text)}catch{data={message:text}}if(!r.ok)throw new Error(data.message||data.error||`Netlify ${r.status}`);return data}

export async function handler(event){if(event.httpMethod!=='POST')return json(405,{error:'Método no permitido'});let deployRow;try{
 const ctx=await authContext(event);const {siteId}=JSON.parse(event.body||'{}');if(!siteId)throw new Error('siteId obligatorio');let site=await siteAccess(ctx,siteId); // clientes con acceso pueden publicar su contenido
 const ins=await ctx.db.from('jmg_deploys').insert({site_id:siteId,status:'building',created_by:ctx.user.id,message:'Compilando HTML estático'}).select().single();deployRow=ins.data;
 const [fr,fieldr,cr,pr]=await Promise.all([ctx.db.from('jmg_files').select('*').eq('site_id',siteId),ctx.db.from('jmg_fields').select('*').eq('site_id',siteId),ctx.db.from('jmg_content').select('*').eq('site_id',siteId),ctx.db.from('jmg_pages').select('*').eq('site_id',siteId)]);for(const r of [fr,fieldr,cr,pr])if(r.error)throw r.error;if(!fr.data?.length)throw new Error('La web no tiene archivos fuente');
 const fieldMap=new Map((fieldr.data||[]).map(f=>[f.field_key,f]));const contentMap=new Map((cr.data||[]).map(c=>[c.field_key,c.value]));const pageMap=new Map((pr.data||[]).map(p=>[p.source_path,p]));const zip=new JSZip();
 for(const f of fr.data){const dl=await ctx.db.storage.from('jmg-source').download(`${siteId}/${f.path}`);if(dl.error)throw dl.error;if(/\.html?$/i.test(f.path)){let html=await dl.data.text();const $=cheerio.load(html,{decodeEntities:false});$('[data-jmg]').each((_,node)=>{const el=$(node),key=el.attr('data-jmg-key'),type=(el.attr('data-jmg')||'text').toLowerCase();if(!key)return;const field=fieldMap.get(key);const value=contentMap.has(key)?contentMap.get(key):field?.default_value;applyField($,el,type,value,field?.settings||{})});applySeo($,pageMap.get(f.path));cleanAttrs($,$.root());html=$.html();zip.file(f.path,html)}else{zip.file(f.path,await dl.data.arrayBuffer())}}
 const zipBytes=await zip.generateAsync({type:'uint8array',compression:'DEFLATE',compressionOptions:{level:6}});
 if(!site.netlify_site_id){const desired=(site.netlify_site_name||`jmg-${site.slug}-${site.id.slice(0,6)}`).toLowerCase().replace(/[^a-z0-9-]/g,'-').slice(0,60);const created=await netlify('/sites',{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({name:desired})});site.netlify_site_id=created.id;site.netlify_site_name=created.name||desired;site.published_url=created.ssl_url||created.url||'';await ctx.db.from('jmg_sites').update({netlify_site_id:site.netlify_site_id,netlify_site_name:site.netlify_site_name,published_url:site.published_url,updated_at:new Date().toISOString()}).eq('id',siteId)}
 const dep=await netlify(`/sites/${site.netlify_site_id}/deploys`,{method:'POST',headers:{'content-type':'application/zip'},body:zipBytes});const deployUrl=dep.ssl_url||dep.deploy_ssl_url||dep.url||site.published_url||'';const mainUrl=site.published_url||dep.ssl_url||dep.url||'';
 await ctx.db.from('jmg_sites').update({status:'active',published_url:mainUrl,updated_at:new Date().toISOString()}).eq('id',siteId);if(deployRow)await ctx.db.from('jmg_deploys').update({status:'ready',provider_deploy_id:dep.id||'',deploy_url:deployUrl,message:'Publicación completada',finished_at:new Date().toISOString()}).eq('id',deployRow.id);await ctx.db.from('jmg_audit_log').insert({user_id:ctx.user.id,site_id:siteId,action:'deploy',detail:{provider:'netlify',deploy_id:dep.id||''}});
 const {data:updated}=await ctx.db.from('jmg_sites').select('*,jmg_organizations(name)').eq('id',siteId).single();return json(200,{ok:true,site:updated,deploy:{id:dep.id,url:deployUrl}})
 }catch(e){console.error(e);try{if(deployRow){const db=adminDb();await db.from('jmg_deploys').update({status:'failed',message:e.message,finished_at:new Date().toISOString()}).eq('id',deployRow.id)}}catch{}return json(400,{error:e.message})}}
