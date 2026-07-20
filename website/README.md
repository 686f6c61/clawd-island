# Claude Island landing

Landing bilingue de Claude Island para la rama `landing`. Está construida con React y Vite, no usa analítica ni servicios propios y muestra capturas del build real de macOS.

## Desarrollo

Requiere Node.js 24 LTS.

```bash
npm ci
npm run dev
```

La build de producción se genera con:

```bash
npm run build
```

## Descarga 1.0.0

La página consulta el release oficial `v1.0.0` del repositorio. El botón de descarga sólo se habilita si el release no es borrador y contiene un ZIP cuyo nombre incluye `claude`. Hasta entonces se muestra un estado de preparación.

El paquete público debe ser universal, estar firmado con Developer ID, usar Hardened Runtime, estar notarizado por Apple y tener el ticket grapado antes de publicarse.

## Publicación

La rama `landing` compila y audita el sitio en GitHub Actions. El directorio desplegable es `website/dist`. No se incluye un workflow de despliegue para evitar vincular el repositorio a un proveedor o dominio sin una decisión explícita.
