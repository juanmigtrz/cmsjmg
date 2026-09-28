(() => {
  const cfg = window.JMG_CONFIG || {};
  const configured = /^https:\/\/.+\.supabase\.co$/.test(cfg.supabaseUrl || '') && cfg.supabaseAnonKey && !cfg.supabaseAnonKey.includes('TU_');
  const db = configured && window.supabase ? window.supabase.createClient(cfg.supabaseUrl, cfg.supabaseAnonKey) : null;
  const $ = (s, r=document) => r.querySelector(s);
  const $$ = (s, r=document) => [...r.querySelectorAll(s)];
  const esc = (s='') => String(s).replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const slugify = (s='') => String(s).toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g,'').replace(/[^a-z0-9]+/g,'-').replace(/(^-|-$)/g,'');
  const fmtDate = d => d ? new Intl.DateTimeFormat('es-ES',{dateStyle:'medium',timeStyle:'short'}).format(new Date(d)) : '—';
  const bytes = n => { n=Number(n||0); if(n<1024)return `${n} B`; if(n<1048576)return `${(n/1024).toFixed(1)} KB`; return `${(n/1048576).toFixed(1)} MB`; };
  const uuid = () => crypto.randomUUID ? crypto.randomUUID() : Math.random().toString(36).slice(2)+Date.now().toString(36);
  function toast(message, type='ok'){
    let el=$('#jmg-toast'); if(!el){el=document.createElement('div');el.id='jmg-toast';el.className='toast';document.body.append(el)}
    el.textContent=message; el.dataset.type=type; el.hidden=false; clearTimeout(toast.t); toast.t=setTimeout(()=>el.hidden=true,3600);
  }
  async function session(){ if(!db)return null; const {data}=await db.auth.getSession(); return data.session; }
  async function profile(){ const s=await session(); if(!s)return null; const {data,error}=await db.from('jmg_profiles').select('*').eq('user_id',s.user.id).maybeSingle(); if(error)throw error; return data; }
  async function requireAuth({staff=false}={}){
    if(!configured || !db){ location.href='index.html?setup=1'; return null; }
    const s=await session(); if(!s){location.href='index.html';return null}
    const p=await profile(); if(!p){await db.auth.signOut();location.href='index.html';return null}
    if(staff && !['superadmin','staff'].includes(p.system_role)){location.href='client.html';return null}
    return {session:s,profile:p};
  }
  async function api(path, body={}){
    const s=await session(); if(!s)throw new Error('Sesión caducada');
    const r=await fetch(`/.netlify/functions/${path}`,{method:'POST',headers:{'content-type':'application/json','authorization':`Bearer ${s.access_token}`},body:JSON.stringify(body)});
    const data=await r.json().catch(()=>({})); if(!r.ok)throw new Error(data.error||`Error ${r.status}`); return data;
  }
  window.JMG={cfg,configured,db,$,$$,esc,slugify,fmtDate,bytes,uuid,toast,session,profile,requireAuth,api};
})();
