# Arquitectura JMG CMS

```text
cms.jmgdigital.es
        │
        ├── Panel JMG
        ├── Panel cliente
        └── Netlify Functions (privadas)
                 │
          ┌──────┴──────┐
          │             │
      Supabase       Netlify API
          │             │
   Auth / DB /       Sites estáticos
   Storage              │
          │        ┌────┼────┐
          │        │    │    │
          └──── contenido    dominios cliente
```

## Fuente y contenido separados
- `jmg-source`: HTML/CSS/JS original, privado.
- `jmg_content`: valores editables.
- `jmg-media`: imágenes subidas desde CMS.
- Deploy: mezcla fuente + contenido y produce HTML final.

## Por qué no es una SPA pública
Las webs de clientes siguen siendo multipágina o la arquitectura que tú programes. JMG CMS no convierte el proyecto en SPA. El deploy genera los mismos archivos que subiste, con el contenido actualizado.

## Por qué el diseño sigue siendo 100% libre
El CMS no tiene componentes visuales obligatorios. Puedes usar CSS puro, Bootstrap, Tailwind compilado, GSAP, Three.js, sliders o cualquier JS que funcione en una web estática. Solo los nodos con `data-jmg` entran en el sistema de contenido.
