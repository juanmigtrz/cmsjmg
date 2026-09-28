# JMG Content Schema v1

JMG CMS no impone plantillas. Tu web puede tener cualquier HTML, CSS y JavaScript. Solo marcas los elementos que quieres hacer editables.

## Texto
```html
<h1
  data-jmg="text"
  data-jmg-key="home.hero.title"
  data-jmg-label="Título principal"
  data-jmg-group="Hero">
  Aquí, como en casa.
</h1>
```

## Texto enriquecido
```html
<div data-jmg="richtext" data-jmg-key="home.about.text" data-jmg-label="Texto" data-jmg-group="Nosotros">
  Texto con <strong>negritas</strong> y enlaces.
</div>
```

## Imagen
```html
<img
  data-jmg="image"
  data-jmg-key="home.hero.image"
  data-jmg-label="Imagen principal"
  data-jmg-group="Hero"
  src="assets/hero.jpg"
  alt="Restaurante">
```
El CMS guarda `src` y `alt`.

## Enlace / botón
```html
<a
  data-jmg="link"
  data-jmg-key="home.hero.cta"
  data-jmg-label="Botón principal"
  data-jmg-group="Hero"
  href="contacto.html">
  Reservar
</a>
```
El CMS guarda URL, texto y target.

## Número
```html
<span data-jmg="number" data-jmg-key="stats.years" data-jmg-label="Años" data-jmg-group="Cifras">23</span>
```

## Color
```html
<input type="color" data-jmg="color" data-jmg-key="brand.accent" data-jmg-label="Color de acento" data-jmg-group="Marca" value="#2338e6">
```

## Mostrar / ocultar
```html
<section data-jmg="toggle" data-jmg-key="home.promo.visible" data-jmg-label="Mostrar promoción" data-jmg-group="Promoción">
  ...
</section>
```

## HTML controlado
Solo úsalo para campos que quieras permitir como HTML completo:
```html
<div data-jmg="html" data-jmg-key="home.custom" data-jmg-label="HTML" data-jmg-group="Avanzado"></div>
```

## Repetidores
Sirven para cartas, servicios, testimonios, miembros, partidos, etc.

```html
<div
  class="services"
  data-jmg="repeater"
  data-jmg-key="home.services"
  data-jmg-label="Servicios"
  data-jmg-group="Servicios">

  <article data-jmg-item>
    <h3 data-jmg-field="title" data-jmg-label="Título">Analítica</h3>
    <p data-jmg-field="text" data-jmg-label="Texto">Medición y dashboards.</p>
  </article>

  <article data-jmg-item>
    <h3 data-jmg-field="title" data-jmg-label="Título">Desarrollo</h3>
    <p data-jmg-field="text" data-jmg-label="Texto">Webs y software.</p>
  </article>
</div>
```

Dentro de cada `data-jmg-item`, los subcampos usan:
- `data-jmg-field="clave"`
- `data-jmg-label="Nombre visible"`
- opcional: `data-jmg-type="image|link|richtext|text"`

## Impedir que el cliente edite un campo
```html
<h2
  data-jmg="text"
  data-jmg-key="internal.claim"
  data-jmg-label="Claim"
  data-jmg-client="false">
  Texto controlado solo por JMG
</h2>
```

## Reglas recomendadas para las claves
Usa claves estables. No las cambies después de que el cliente haya empezado a editar.

Formato recomendado:
`pagina.seccion.campo`

Ejemplos:
- `home.hero.title`
- `home.hero.image`
- `contact.phone`
- `menu.items`
- `services.list`

Una misma clave puede aparecer en varias páginas si quieres que compartan el mismo contenido (por ejemplo, teléfono o CTA global).

## Qué ocurre al publicar
1. JMG CMS toma los archivos originales privados de `jmg-source`.
2. Sustituye cada `data-jmg-key` por el contenido guardado.
3. Aplica el SEO de cada HTML.
4. Elimina los atributos internos `data-jmg*` del HTML público.
5. Genera un ZIP estático.
6. Lo despliega en Netlify.

La web pública no consulta Supabase para renderizar textos. Recibe HTML ya compilado.
