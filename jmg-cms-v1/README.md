# JMG CMS v1

CMS central multi-cliente para JMG Digital. Permite subir cualquier proyecto HTML/CSS/JS, marcar contenido editable con `data-jmg`, dar a cada cliente un panel limitado y publicar HTML estático en Netlify.

## Incluye
- Panel JMG multi-cliente.
- Panel simplificado para clientes.
- Organizaciones, webs, usuarios y roles.
- Importación de proyectos ZIP.
- Explorador/editor de archivos fuente.
- Detección automática de campos `data-jmg`.
- Texto, rich text, imagen, enlace, número, color, toggle, HTML y repetidores.
- Biblioteca de imágenes.
- SEO por página.
- Historial de deploys.
- Build server-side que genera HTML estático.
- Creación automática de un site Netlify en el primer deploy.
- Supabase Auth + RLS + Storage.

## Instalación

### 1. Crear proyecto Supabase
Recomendado: un proyecto dedicado exclusivamente a JMG CMS.

En Supabase > SQL Editor ejecuta completo:
`supabase/schema.sql`

### 2. Crear tu usuario JMG
En Supabase > Authentication > Users crea tu usuario.
Copia su UUID y ejecuta:
```sql
update public.jmg_profiles
set system_role='superadmin'
where user_id='TU_UUID';
```

### 3. Configurar frontend
Edita `public/assets/js/config.js`:
```js
window.JMG_CONFIG = {
  supabaseUrl: 'https://TU-PROYECTO.supabase.co',
  supabaseAnonKey: 'TU_PUBLISHABLE_KEY',
  cmsName: 'JMG CMS'
};
```
La publishable/anon key puede estar en frontend. NO pongas aquí la service role key.

### 4. Subir JMG CMS a Netlify
Sube esta carpeta a un site de Netlify (idealmente `cms.jmgdigital.es`).
Netlify detectará `netlify.toml` y las Functions.

### 5. Variables privadas de Netlify
En Site configuration > Environment variables crea:
- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`
- `NETLIFY_AUTH_TOKEN`

`NETLIFY_AUTH_TOKEN` es un Personal Access Token de la cuenta/equipo de Netlify donde JMG alojará las webs.

Haz un nuevo deploy después de añadir las variables.

### 6. Entrar
Abre `/` e inicia sesión.
Tu cuenta superadmin entra en `admin.html`.
Los clientes entran por el mismo login y son enviados a `client.html`.

## Primera web
1. JMG CMS > Clientes > Nuevo cliente.
2. JMG CMS > Webs > Nueva web.
3. Marca los contenidos editables en tu HTML según `docs/JMG-CONTENT-SCHEMA.md`.
4. Comprime la web en ZIP.
5. Web > Importar web > sube el ZIP.
6. Revisa “Campos editables” y desactiva lo que no quieras que toque el cliente.
7. Pulsa “Publicar cambios”.
8. En el primer deploy JMG CMS crea automáticamente el site en Netlify.
9. En Netlify conecta el dominio del cliente al site creado.

## Dar acceso al cliente
En JMG CMS > Usuarios > Invitar usuario. Elige cliente y rol.
El cliente recibe el email de Supabase y, al entrar, solo ve las webs de su organización y los campos que hayas marcado como editables.

## Demo
`demo-site.zip` es una web de ejemplo lista para importar.

## Seguridad
- El código fuente está en un bucket privado (`jmg-source`).
- La service role key y el token de Netlify solo viven en Functions/variables de entorno.
- El cliente no tiene permisos RLS para modificar código ni estructura.
- El cliente solo puede editar `jmg_content` cuando `client_editable=true`.
- El SEO del cliente se actualiza mediante una RPC que limita las columnas modificables.
- El HTML público se compila server-side; no expone claves `data-jmg` ni necesita consultar la base de datos para mostrar contenido.

## Importante antes de producción masiva
Esta v1 es funcional para validar y empezar con clientes. Antes de convertirla en infraestructura crítica de decenas/cientos de webs conviene añadir: backups automáticos, versionado/rollback de código y contenido, cola de builds, logs de errores más detallados, rate limiting, 2FA/SSO si lo necesitas y pruebas automáticas de deploy.
