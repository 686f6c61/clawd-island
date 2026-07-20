# Design QA — Claude Island landing

## Estado final

`final result: passed`

## Fuente de verdad

- Referencia visual: `Captura de pantalla 2026-07-20 a las 13.48.56.png`, aportada en la conversación.
- Implementación: `http://localhost:4173/`
- Estado principal comparado: español, sección Funciones, viewport 1324 × 778.
- Comparación lado a lado actual: `design-qa-artifacts/landing-features-reference-comparison-v3.png`.

La implementación conserva la intención de la referencia —retícula editorial, bordes duros, tipografía de gran escala, eco en contorno y paneles asimétricos— y la adapta a la identidad coral, marfil y negro de Clawd. El globo técnico de la referencia se sustituye deliberadamente por la mascota real del producto.

## Evidencias

- Escritorio, inicio: `design-qa-artifacts/landing-desktop-v2.png`.
- Escritorio, capturas reales: `design-qa-artifacts/landing-desktop-gallery-v2.png`.
- Escritorio, changelog: `design-qa-artifacts/landing-desktop-changelog-v2.png`.
- Móvil, inicio corregido: `design-qa-artifacts/landing-mobile-v2.png`.
- Móvil, galería: `design-qa-artifacts/landing-mobile-gallery-v2.png`.
- Móvil, descarga: `design-qa-artifacts/landing-mobile-end-v2.png`.
- Escritorio, seis beneficios con Clawd: `design-qa-artifacts/landing-features-desktop-v3.png`.
- Móvil, beneficios con Clawd: `design-qa-artifacts/landing-features-mobile-v3.png`.
- Auditoría visual final, escritorio: `design-qa-artifacts/audit-2026-07-20/02-features-after.png` y `design-qa-artifacts/audit-2026-07-20/05-download-after.png`.
- Auditoría visual final, móvil: `design-qa-artifacts/audit-2026-07-20/07-mobile-features-after.png` y `design-qa-artifacts/audit-2026-07-20/06b-mobile-update-panel-after.png`.
- Comparaciones antes/después: `design-qa-artifacts/audit-2026-07-20/features-before-after-v4.png` y `design-qa-artifacts/audit-2026-07-20/download-before-after-v4.png`.

Los artefactos son evidencia local de QA y no se versionan para no inflar el repositorio. Las tres capturas de producto empleadas por la web sí forman parte de `public/assets`.

## Comparación y correcciones

### Pase 1

- **P2 — Responsividad / tipografía:** el wordmark `CLAUDE_ISLAND` se recortaba a 390 px. Impacto: la marca parecía rota al cargar la página en móvil.
- **Corrección:** se ajustaron el tamaño fluido, la altura mínima del bloque del título y el tamaño de la mascota para conservar la jerarquía sin desbordamiento.
- **Evidencia posterior:** `landing-mobile-v2.png`; ancho de documento y viewport: 390 px, sin overflow horizontal ni recorte.

### Pase 2

- No quedaron hallazgos P0, P1 o P2.
- La mayor altura del hero y la mascota Clawd en lugar del globo son adaptaciones intencionales al producto, no defectos de fidelidad.

### Pase 3 — beneficios de producto

- **P2 — Imágenes / equilibrio visual:** `Clawd-menu.svg` usa un `viewBox` mucho más cerrado que los otros cinco estados y en la primera captura ocupaba casi todo el panel, rompiendo la cadencia de la retícula.
- **Corrección:** se normalizó sólo la huella visible de esa mascota a 48 × 52 px en escritorio y 52 × 56 px en móvil; los demás estados conservan su lienzo original para no recortar las animaciones.
- **Evidencia posterior:** `landing-features-desktop-v3.png` y `landing-features-reference-comparison-v3.png`; las seis escenas tienen peso óptico equivalente, bordes alineados y alturas de tarjeta de 356–357 px.
- **Copy:** las seis tarjetas se reescribieron como resultados para el usuario. Se retiraron nombres internos y detalles de implementación (`AskUserQuestion`, hooks, HMAC y replay) sin perder las funciones reales del producto.
- **Estado final del pase:** no quedan hallazgos P0, P1 o P2; seis recursos cargados, cero imágenes rotas y cero overflow a 1324 × 778 y 390 × 844.

### Pase 4 — contraste y escala de las animaciones

- **P1 — Contraste / actualización:** el cuerpo coral de `Clawd-update.svg` coincidía con el fondo coral del panel y desaparecía visualmente; sólo se distinguían los ojos y el cartel.
- **Corrección:** el panel de actualización usa ahora marfil claro con una regla coral superior. La animación crece hasta 460 px sin recorte y mantiene el coral como acento de marca.
- **P2 — Jerarquía / funciones:** las animaciones de las seis tarjetas quedaban pequeñas dentro de sus marcos y perdían presencia frente al texto.
- **Corrección:** los cinco estados de lienzo amplio pasan de 128 a 200 px en escritorio y de 140 a 220 px en móvil. `Clawd-menu.svg` conserva una medida óptica específica —70 × 76 px y 78 × 84 px— porque su `viewBox` es más cerrado.
- **Comparación:** `audit-2026-07-20/download-before-after-v4.png` confirma que la mascota completa vuelve a leerse; `features-before-after-v4.png` confirma mayor presencia sin romper la retícula.
- **Revisión global:** hero, galería de capturas reales, changelog, navegación y pie mantienen el sistema editorial original y no requirieron rediseño.
- **Estado final del pase:** escritorio y móvil sin overflow horizontal, imágenes rotas, recortes ni mensajes de consola.

### Pase 5 — enlace social del footer

- **P3 — Claridad de autoría:** el nombre del creador enlazaba a su perfil, pero el footer no identificaba explícitamente la red social.
- **Corrección:** se añadió una línea visible de X / Twitter con el icono Phosphor `XLogo` y el usuario `@686f6c61`; tanto el nombre del creador como el enlace social apuntan a `https://x.com/686f6c61`.
- **Evidencia:** `design-qa-artifacts/audit-footer-2026-07-20/footer-before-after.png`, `footer-after-desktop.png` y `footer-after-mobile.png`.
- **Estado final del pase:** enlace accesible por nombre, foco de teclado conservado y composición correcta en escritorio y móvil.

## Cobertura

- **Fuentes y tipografía:** Archivo Variable para el display y Space Grotesk Variable para texto; pesos, tracking, contornos, saltos ES/EN y jerarquía revisados.
- **Espaciado y layout:** grid, bordes, alineación, ritmo vertical, densidad, recortes y anchuras comprobados en 1324 × 778 y 390 × 844.
- **Colores:** coral Clawd, marfil y negro con contraste legible; no se usan gradientes decorativos ni sombras genéricas.
- **Imágenes:** seis SVG originales de estados Clawd y capturas reales; proporciones, recorte, nitidez y función decorativa verificados; cero imágenes rotas. El recurso de actualización sigue reservado a una actualización real.
- **Copy:** español e inglés completos y orientados a beneficios; aviso de marca de Anthropic, requisitos y estado de descarga coherentes.
- **Iconos:** una única familia Phosphor, alineada y con tamaño consistente.
- **Interacciones:** navegación por anclas, cambio ES/EN, estado de release disponible/no disponible, enlaces externos y foco de teclado comprobados.
- **Accesibilidad:** landmarks semánticos, orden de encabezados, enlace de salto, `lang` dinámico, `aria-pressed`, foco visible, alt text y `prefers-reduced-motion` revisados.
- **Consola:** sin errores ni advertencias en escritorio o móvil.
