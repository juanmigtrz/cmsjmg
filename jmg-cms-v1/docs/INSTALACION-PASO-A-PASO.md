# Instalación de JMG CMS · paso a paso

## A. Supabase (una sola vez)
1. Crea un proyecto nuevo llamado `JMG CMS`.
2. SQL Editor > New query.
3. Copia todo `supabase/schema.sql` y pulsa Run.
4. Authentication > Users > Add user > crea tu cuenta JMG.
5. Copia el UUID del usuario.
6. SQL Editor y ejecuta:
```sql
update public.jmg_profiles
set system_role='superadmin'
where user_id='TU_UUID';
```
7. Project Settings / API: copia Project URL y Publishable key.
8. Project Settings / API: copia también la Service Role key. Esta última NO se pone en HTML.

## B. Configurar los archivos
Abre `public/assets/js/config.js` y cambia:
- `supabaseUrl`
- `supabaseAnonKey`

## C. Crear el CMS en Netlify
Para el CMS central usa un deploy con build (Git o Netlify CLI), porque las funciones necesitan dependencias Node.

### Opción recomendada: GitHub + Netlify
1. Crea un repositorio privado `jmg-cms`.
2. Sube el contenido de esta carpeta.
3. Netlify > Add new project > Import an existing project > GitHub.
4. Selecciona `jmg-cms`.
5. Publish directory: `public`
6. Functions directory: Netlify leerá `netlify.toml`.
7. Deploy.

### Variables de entorno
Netlify > Site configuration > Environment variables:
- `SUPABASE_URL` = URL del proyecto.
- `SUPABASE_SERVICE_ROLE_KEY` = Service Role key.
- `NETLIFY_AUTH_TOKEN` = Personal Access Token de Netlify.

Después haz Trigger deploy.

## D. Token de Netlify
En tu cuenta de Netlify crea un Personal Access Token para JMG CMS. El token permite que el CMS cree y publique sites de clientes. Guárdalo solo como variable de entorno.

## E. Dominio del CMS
En Netlify > Domain management conecta, por ejemplo:
`cms.jmgdigital.es`

En Supabase > Authentication > URL Configuration:
- Site URL: `https://cms.jmgdigital.es`
- Redirect URLs: añade `https://cms.jmgdigital.es/**`

Esto es necesario para las invitaciones de clientes.

## F. Probar
1. Entra en `https://cms.jmgdigital.es`.
2. Crea un cliente.
3. Crea una web.
4. Importa `demo-site.zip`.
5. Comprueba que aparecen los campos editables.
6. Pulsa Publicar cambios.
7. El primer deploy crea automáticamente un site de Netlify.

## G. Conectar el dominio del cliente
En el site creado automáticamente en Netlify:
1. Domain management.
2. Add a domain.
3. Añade el dominio del cliente.
4. Configura DNS según indique Netlify.

JMG CMS guarda el site ID y a partir de ahí todos los siguientes deploys se publican en ese mismo site.
