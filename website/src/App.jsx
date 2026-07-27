import { useEffect, useMemo, useState } from "react";
import {
  ArrowDown,
  ArrowRight,
  ArrowUpRight,
  Check,
  Cpu,
  GithubLogo,
  GlobeHemisphereWest,
  XLogo,
} from "@phosphor-icons/react";

const REPOSITORY = "https://github.com/686f6c61/clawd-island";
const RELEASE_CANDIDATES = [
  {
    state: "available",
    url: "https://api.github.com/repos/686f6c61/clawd-island/releases/tags/v1.0.0",
  },
  {
    state: "beta",
    url: "https://api.github.com/repos/686f6c61/clawd-island/releases/tags/v0.2.0",
  },
  {
    state: "beta",
    url: "https://api.github.com/repos/686f6c61/clawd-island/releases/tags/v0.1.0-beta.1",
  },
];
const APPLE_OPEN_GUIDE =
  "https://support.apple.com/guide/mac-help/open-a-mac-app-from-an-unknown-developer-mh40616/mac";

const featureMascots = [
  "clawd-menu.svg",
  "clawd-waiting.svg",
  "clawd-working.svg",
  "clawd-idle.svg",
  "clawd-completed.svg",
  "clawd-failed.svg",
];

const copy = {
  es: {
    skip: "Saltar al contenido",
    nav: {
      features: "Funciones",
      screens: "En uso",
      changelog: "Cambios",
      download: "Descarga",
    },
    eyebrow: "Superficie nativa para macOS",
    heroLine: "Claude Code. Sin perder el hilo.",
    heroBody:
      "Tus sesiones, preguntas y permisos viven en la parte superior del Mac. Mira qué necesita atención y vuelve a la terminal correcta con un gesto.",
    heroNote:
      "Sin backend propio. Sin telemetría. El contexto de tus proyectos se queda en tu Mac.",
    releaseStatus: "Próxima versión pública",
    releaseLabel: "Edición de lanzamiento",
    releaseBody:
      "La descarga se habilitará únicamente cuando el paquete universal esté firmado con Developer ID, notarizado por Apple y publicado como release oficial.",
    betaReleaseStatus: "Beta pública disponible",
    betaReleaseLabel: "Compilación de prueba",
    betaReleaseBody:
      "Puedes probar Claude Island antes del lanzamiento estable. Esta beta es universal, pero todavía no está firmada con Developer ID ni notarizada por Apple.",
    releaseUnavailable: "Descarga en preparación",
    releaseAvailable: "Descargar para macOS",
    betaAvailable: "Descargar beta 0.2.0",
    source: "Ver código fuente",
    proof: "Producto real / captura real",
    sectionFeatures: "Todo tu trabajo, a la vista",
    sectionFeaturesBody:
      "Claude Island te dice qué está pasando, qué necesita una respuesta y dónde volver, sin obligarte a recorrer ventanas.",
    features: [
      {
        title: "Todas tus sesiones, en una sola vista",
        body: "Comprueba qué está trabajando, esperando o terminado aunque tengas muchas terminales y agentes abiertos.",
      },
      {
        title: "Responde sin cambiar de contexto",
        body: "Contesta preguntas y concede permisos desde la Island, sin buscar qué ventana estaba esperando.",
      },
      {
        title: "Vuelve a la terminal correcta",
        body: "Un toque te lleva a Ghostty, Terminal, iTerm2 o Warp, justo al lugar donde continúa el trabajo.",
      },
      {
        title: "Anticípate a tus límites",
        body: "Consulta tu uso de cinco horas y semanal antes de que un límite interrumpa una sesión importante.",
      },
      {
        title: "Encaja en cualquier Mac",
        body: "Con notch o sin él, la Island se coloca automáticamente donde resulta cómoda y siempre visible.",
      },
      {
        title: "Lo importante te encuentra",
        body: "Clawd aparece cuando una sesión termina, falla o necesita tu atención para que nada quede olvidado.",
      },
    ],
    galleryEyebrow: "La aplicación, no un mockup",
    galleryTitle: "Mírala trabajando.",
    galleryBody:
      "Estado compacto, control de sesiones y ajustes nativos. Las capturas pertenecen al build real de macOS.",
    shots: {
      compact: "Island compacta / sesión trabajando",
      menu: "Menú / sesiones y terminal",
      settings: "Ajustes / uso y comportamiento",
    },
    changelogEyebrow: "Registro público",
    changelogTitle: "Camino a 1.0.0",
    changelogBody:
      "El lanzamiento agrupa la Island nativa, el control de sesiones y el endurecimiento necesario para distribuir una app de macOS con garantías.",
    changelogGroups: [
      {
        label: "Añadido",
        items: [
          "Island nativa para notch y borde superior.",
          "Monitorización multisesión y de subagentes.",
          "Respuestas a preguntas y permisos.",
          "Ghostty, Terminal, iTerm2 y Warp.",
          "Uso de Claude y mascotas Clawd / Clawdia.",
        ],
      },
      {
        label: "Seguridad",
        items: [
          "Autenticación HMAC mutua y rechazo de replay.",
          "Parsing acotado y permisos privados de soporte.",
          "Gate de firma, Hardened Runtime y notarización.",
          "Feed de actualizaciones firmado con Sparkle.",
        ],
      },
      {
        label: "0.2.0",
        items: [
          "Certificate pinning para la API de uso de Anthropic.",
          "Borrado seguro del token y endurecimiento de permisos.",
          "Corregido crash cuando no hay pantalla disponible.",
          "AppleScript ya no bloquea el hilo principal.",
          "Accesibilidad VoiceOver restaurada.",
          "Los ajustes ya no destruyen el estado de SwiftUI.",
        ],
      },
    ],
    fullChangelog: "Ver changelog completo",
    downloadEyebrow: "Release verificable",
    downloadTitle: "Una descarga. Dos arquitecturas.",
    downloadBody:
      "El paquete oficial será universal para Apple Silicon e Intel. Publicaremos checksum, inventario de dependencias y feed de actualización firmado junto al ZIP notarizado.",
    betaDownloadEyebrow: "Beta pública",
    betaDownloadTitle: "Pruébala ya en tu Mac.",
    betaDownloadBody:
      "Descarga la beta 0.2.0 para Apple Silicon o Intel. No necesita la App Store y contiene la aplicación real que estamos preparando para el lanzamiento estable.",
    platformPrimary: "Nativa para Apple Silicon",
    platformSecondary: "También compatible con Mac Intel",
    safeguards: [
      "Developer ID + Hardened Runtime",
      "Notarización y ticket grapado",
      "Apple Silicon + Intel",
      "Actualizaciones Sparkle firmadas",
    ],
    betaSafeguards: [
      "Apple Silicon + Intel",
      "Código fuente público",
      "Sin backend ni telemetría",
      "Firma y notarización pendientes",
    ],
    requirement: "Requiere macOS 14 o posterior y Claude Code instalado.",
    betaRequirement: "Beta 0.1.0 · Requiere macOS 14 o posterior y Claude Code instalado.",
    betaWarningTitle: "Beta sin notarizar",
    betaWarning:
      "macOS puede bloquear el primer arranque. Intenta abrir la app y después usa Ajustes del Sistema → Privacidad y seguridad → Abrir igualmente. No desactives Gatekeeper.",
    betaOpenGuide: "Ver instrucciones oficiales de Apple",
    legal:
      "Claude y Claude Code son marcas de Anthropic PBC. Claude Island es un proyecto independiente y no está afiliado, patrocinado ni respaldado por Anthropic.",
    creator: "Creado por",
    language: "Idioma",
    loading: "Comprobando release…",
  },
  en: {
    skip: "Skip to content",
    nav: {
      features: "Features",
      screens: "In use",
      changelog: "Changelog",
      download: "Download",
    },
    eyebrow: "Native macOS control surface",
    heroLine: "Claude Code. Never lose the thread.",
    heroBody:
      "Your sessions, questions and permissions live at the top of your Mac. See what needs attention and return to the right terminal in one gesture.",
    heroNote:
      "No project backend. No telemetry. Your project context stays on your Mac.",
    releaseStatus: "Next public release",
    releaseLabel: "Launch edition",
    releaseBody:
      "The download will unlock only after the universal package is Developer ID signed, Apple-notarized and published as an official release.",
    betaReleaseStatus: "Public beta available",
    betaReleaseLabel: "Testing build",
    betaReleaseBody:
      "You can try Claude Island before the stable launch. This beta is universal, but it is not yet Developer ID signed or Apple-notarized.",
    releaseUnavailable: "Download in preparation",
    releaseAvailable: "Download for macOS",
    betaAvailable: "Download beta 0.1.0",
    source: "View source code",
    proof: "Real product / real capture",
    sectionFeatures: "All your work, at a glance",
    sectionFeaturesBody:
      "Claude Island shows what is happening, what needs an answer and where to return without making you hunt through windows.",
    features: [
      {
        title: "Every session in one view",
        body: "See what is working, waiting or finished even when you have many terminals and agents open.",
      },
      {
        title: "Reply without losing context",
        body: "Answer questions and grant permissions from the Island without searching for the window that is waiting.",
      },
      {
        title: "Return to the right terminal",
        body: "One tap takes you to Ghostty, Terminal, iTerm2 or Warp, exactly where the work continues.",
      },
      {
        title: "Stay ahead of your limits",
        body: "Check your five-hour and weekly usage before a limit interrupts an important session.",
      },
      {
        title: "Fits every Mac",
        body: "With or without a notch, the Island places itself where it stays comfortable and always visible.",
      },
      {
        title: "What matters finds you",
        body: "Clawd appears when a session finishes, fails or needs attention so nothing gets forgotten.",
      },
    ],
    galleryEyebrow: "The application, not a mockup",
    galleryTitle: "See it at work.",
    galleryBody:
      "Compact state, session control and native settings. Every screenshot comes from the real macOS build.",
    shots: {
      compact: "Compact Island / working session",
      menu: "Menu / sessions and terminal",
      settings: "Settings / usage and behaviour",
    },
    changelogEyebrow: "Public record",
    changelogTitle: "Road to 1.0.0",
    changelogBody:
      "The launch brings together the native Island, session control and the hardening required to distribute a trustworthy macOS app.",
    changelogGroups: [
      {
        label: "Added",
        items: [
          "Native notch and top-edge Island.",
          "Multi-session and subagent monitoring.",
          "Question and permission responses.",
          "Ghostty, Terminal, iTerm2 and Warp.",
          "Claude usage and Clawd / Clawdia mascots.",
        ],
      },
      {
        label: "Security",
        items: [
          "Mutual HMAC authentication and replay rejection.",
          "Bounded parsing and private support permissions.",
          "Signing, Hardened Runtime and notarization gate.",
          "Signed Sparkle update feed.",
        ],
      },
      {
        label: "0.2.0",
        items: [
          "Certificate pinning for the Anthropic usage API.",
          "Secure token deletion and directory permission hardening.",
          "Crash fix when no display is available.",
          "AppleScript no longer blocks the main thread.",
          "VoiceOver accessibility restored.",
          "Settings no longer destroy SwiftUI state.",
        ],
      },
    ],
    fullChangelog: "View full changelog",
    downloadEyebrow: "Verifiable release",
    downloadTitle: "One download. Two architectures.",
    downloadBody:
      "The official package will be universal for Apple Silicon and Intel. A checksum, dependency inventory and signed update feed will ship beside the notarized ZIP.",
    betaDownloadEyebrow: "Public beta",
    betaDownloadTitle: "Try it on your Mac today.",
    betaDownloadBody:
      "Download the 0.2.0 beta for Apple Silicon or Intel. It does not require the App Store and contains the real app we are preparing for the stable launch.",
    platformPrimary: "Native on Apple Silicon",
    platformSecondary: "Also compatible with Intel Macs",
    safeguards: [
      "Developer ID + Hardened Runtime",
      "Notarized and stapled",
      "Apple Silicon + Intel",
      "Signed Sparkle updates",
    ],
    betaSafeguards: [
      "Apple Silicon + Intel",
      "Public source code",
      "No backend or telemetry",
      "Signing and notarization pending",
    ],
    requirement: "Requires macOS 14 or later and Claude Code installed.",
    betaRequirement: "Beta 0.2.0 · Requires macOS 14 or later and Claude Code installed.",
    betaWarningTitle: "Unnotarized beta",
    betaWarning:
      "macOS may block the first launch. Try opening the app, then use System Settings → Privacy & Security → Open Anyway. Do not disable Gatekeeper.",
    betaOpenGuide: "View Apple's official instructions",
    legal:
      "Claude and Claude Code are trademarks of Anthropic PBC. Claude Island is an independent project and is not affiliated with, sponsored by, or endorsed by Anthropic.",
    creator: "Created by",
    language: "Language",
    loading: "Checking release…",
  },
};

function useOfficialRelease() {
  const [status, setStatus] = useState({ state: "loading", url: null });

  useEffect(() => {
    const controller = new AbortController();

    async function findRelease() {
      try {
        for (const candidate of RELEASE_CANDIDATES) {
          const response = await fetch(candidate.url, {
            headers: { Accept: "application/vnd.github+json" },
            signal: controller.signal,
          });
          if (response.status === 404) continue;
          if (!response.ok) throw new Error(`GitHub returned ${response.status}`);

          const release = await response.json();
          const zip = release?.assets?.find(
            (asset) =>
              asset.name.endsWith(".zip") &&
              asset.name.toLowerCase().includes("claude"),
          );
          if (release && !release.draft && zip) {
            setStatus({ state: candidate.state, url: zip.browser_download_url });
            return;
          }
        }
        setStatus({ state: "upcoming", url: null });
      } catch (error) {
        if (error.name !== "AbortError") setStatus({ state: "upcoming", url: null });
      }
    }

    findRelease();

    return () => controller.abort();
  }, []);

  return status;
}

function ReleaseButton({ release, t, compact = false }) {
  if (release.state === "available" || release.state === "beta") {
    return (
      <a
        className={`button button-primary${compact ? " button-compact" : ""}`}
        href={release.url}
      >
        {release.state === "beta" ? t.betaAvailable : t.releaseAvailable}
        <ArrowDown size={18} weight="bold" aria-hidden="true" />
      </a>
    );
  }

  return (
    <span
      className={`button button-disabled${compact ? " button-compact" : ""}`}
      aria-disabled="true"
    >
      {release.state === "loading" ? t.loading : t.releaseUnavailable}
    </span>
  );
}

function Eyebrow({ children, light = false }) {
  return <p className={`eyebrow${light ? " eyebrow-light" : ""}`}>{children}</p>;
}

export function App() {
  const [language, setLanguage] = useState(() => {
    const saved = window.localStorage.getItem("claude-island-language");
    if (saved === "es" || saved === "en") return saved;
    return window.navigator.language.toLowerCase().startsWith("es") ? "es" : "en";
  });
  const release = useOfficialRelease();
  const t = useMemo(() => copy[language], [language]);
  const isStableRelease = release.state === "available";

  useEffect(() => {
    window.localStorage.setItem("claude-island-language", language);
    document.documentElement.lang = language;
    document.title =
      language === "es"
        ? "Claude Island — Claude Code en el notch de tu Mac"
        : "Claude Island — Claude Code on your MacBook notch";
  }, [language]);

  return (
    <>
      <a className="skip-link" href="#main-content">
        {t.skip}
      </a>

      <div className="page-shell">
        <header className="topbar" aria-label="Primary navigation">
          <a className="brand" href="#top" aria-label="Claude Island home">
            <span className="brand-mark">
              <img src="/assets/app-icon.svg" alt="" />
            </span>
            <span>CLAUDE_ISLAND</span>
          </a>

          <nav className="main-nav" aria-label="Sections">
            <a href="#features">{t.nav.features}</a>
            <a href="#screens">{t.nav.screens}</a>
            <a href="#changelog">{t.nav.changelog}</a>
            <a href="#download">{t.nav.download}</a>
          </nav>

          <div className="top-actions">
            <div className="language-toggle" aria-label={t.language}>
              <GlobeHemisphereWest size={17} aria-hidden="true" />
              {[
                ["es", "ES"],
                ["en", "EN"],
              ].map(([code, label]) => (
                <button
                  key={code}
                  type="button"
                  className={language === code ? "is-active" : ""}
                  aria-pressed={language === code}
                  onClick={() => setLanguage(code)}
                >
                  {label}
                </button>
              ))}
            </div>
            <a
              className="icon-link"
              href={REPOSITORY}
              aria-label="GitHub"
              target="_blank"
              rel="noreferrer"
            >
              <GithubLogo size={22} weight="bold" />
            </a>
          </div>
        </header>

        <main id="main-content">
          <section className="hero" id="top">
            <div className="hero-heading">
              <Eyebrow>{t.eyebrow}</Eyebrow>
              <div className="hero-wordmark" aria-label="Claude Island">
                <span className="wordmark-solid">CLAUDE_ISLAND</span>
                <span className="wordmark-outline" aria-hidden="true">
                  CLAUDE_ISLAND
                </span>
              </div>
            </div>
            <div className="hero-clawd" aria-hidden="true">
              <img src="/assets/clawd-working.svg" alt="" />
              <span>ACTIVE / 01</span>
            </div>
          </section>

          <section className="hero-grid" aria-label="Product overview">
            <div className="hero-copy panel-cell">
              <h1>{t.heroLine}</h1>
              <p>{t.heroBody}</p>
              <p className="small-note">{t.heroNote}</p>
            </div>

            <div className="island-proof panel-cell">
              <span className="proof-label">{t.proof}</span>
              <div className="island-image-wrap">
                <img
                  src="/assets/compact-island.png"
                  alt={t.shots.compact}
                />
              </div>
            </div>

            <div
              className="version-panel panel-cell"
              aria-label={isStableRelease ? "Version 1.0.0" : "Version 0.1 beta"}
            >
              <span className="version-kicker">
                {isStableRelease ? t.releaseStatus : t.betaReleaseStatus}
              </span>
              <strong>{isStableRelease ? "1.0.0" : "0.1 β"}</strong>
            </div>

            <div className="release-panel panel-cell">
              <div>
                <Eyebrow>
                  {isStableRelease ? t.releaseLabel : t.betaReleaseLabel}
                </Eyebrow>
                <p>{isStableRelease ? t.releaseBody : t.betaReleaseBody}</p>
              </div>
              <div className="release-actions">
                <ReleaseButton release={release} t={t} compact />
                <a className="text-link" href={REPOSITORY}>
                  {t.source}
                  <ArrowUpRight size={17} weight="bold" aria-hidden="true" />
                </a>
              </div>
            </div>
          </section>

          <section className="features-section" id="features">
            <div className="section-intro">
              <Eyebrow>01 / {t.nav.features}</Eyebrow>
              <h2>{t.sectionFeatures}</h2>
              <p>{t.sectionFeaturesBody}</p>
            </div>

            <div className="feature-grid">
              {t.features.map((feature, index) => {
                return (
                  <article className="feature-card" key={feature.title}>
                    <div className="feature-topline">
                      <span>{String(index + 1).padStart(2, "0")}</span>
                      <span>CLAWD / {String(index + 1).padStart(2, "0")}</span>
                    </div>
                    <div className="feature-mascot" aria-hidden="true">
                      <img
                        src={`/assets/${featureMascots[index]}`}
                        alt=""
                      />
                    </div>
                    <div className="feature-copy">
                      <h3>{feature.title}</h3>
                      <p>{feature.body}</p>
                    </div>
                  </article>
                );
              })}
            </div>
          </section>

          <section className="gallery-section" id="screens">
            <div className="gallery-heading">
              <div>
                <Eyebrow light>02 / {t.galleryEyebrow}</Eyebrow>
                <h2>{t.galleryTitle}</h2>
              </div>
              <p>{t.galleryBody}</p>
            </div>

            <div className="gallery-grid">
              <figure className="shot shot-compact">
                <figcaption>
                  <span>01</span>
                  {t.shots.compact}
                </figcaption>
                <div className="shot-canvas compact-canvas">
                  <img src="/assets/compact-island.png" alt={t.shots.compact} />
                </div>
              </figure>

              <figure className="shot shot-menu">
                <figcaption>
                  <span>02</span>
                  {t.shots.menu}
                </figcaption>
                <div className="shot-canvas menu-canvas">
                  <img src="/assets/menu.png" alt={t.shots.menu} />
                </div>
              </figure>

              <figure className="shot shot-settings">
                <figcaption>
                  <span>03</span>
                  {t.shots.settings}
                </figcaption>
                <div className="shot-canvas settings-canvas">
                  <img src="/assets/settings.png" alt={t.shots.settings} />
                </div>
              </figure>
            </div>
          </section>

          <section className="changelog-section" id="changelog">
            <div className="changelog-number" aria-hidden="true">
              1.0
            </div>
            <div className="changelog-copy">
              <Eyebrow>03 / {t.changelogEyebrow}</Eyebrow>
              <h2>{t.changelogTitle}</h2>
              <p>{t.changelogBody}</p>
              <a className="text-link" href={`${REPOSITORY}/blob/main/CHANGELOG.md`}>
                {t.fullChangelog}
                <ArrowUpRight size={17} weight="bold" aria-hidden="true" />
              </a>
            </div>
            <div className="changelog-groups">
              {t.changelogGroups.map((group) => (
                <div className="change-group" key={group.label}>
                  <h3>{group.label}</h3>
                  <ul>
                    {group.items.map((item) => (
                      <li key={item}>
                        <ArrowRight size={15} weight="bold" aria-hidden="true" />
                        <span>{item}</span>
                      </li>
                    ))}
                  </ul>
                </div>
              ))}
            </div>
          </section>

          <section className="download-section" id="download">
            <div className="download-copy">
              <Eyebrow light>
                04 / {isStableRelease ? t.downloadEyebrow : t.betaDownloadEyebrow}
              </Eyebrow>
              <h2>{isStableRelease ? t.downloadTitle : t.betaDownloadTitle}</h2>
              <p>{isStableRelease ? t.downloadBody : t.betaDownloadBody}</p>
              <div className="platform-badge">
                <Cpu size={23} weight="bold" aria-hidden="true" />
                <span>
                  <strong>{t.platformPrimary}</strong>
                  <small>{t.platformSecondary}</small>
                </span>
              </div>
              <div className="download-actions">
                <ReleaseButton release={release} t={t} />
                <a className="button button-ghost" href={`${REPOSITORY}/releases`}>
                  GitHub Releases
                  <ArrowUpRight size={18} weight="bold" aria-hidden="true" />
                </a>
              </div>
              {release.state === "beta" && (
                <aside className="beta-notice" aria-label={t.betaWarningTitle}>
                  <strong>{t.betaWarningTitle}</strong>
                  <p>{t.betaWarning}</p>
                  <a href={APPLE_OPEN_GUIDE} target="_blank" rel="noreferrer">
                    {t.betaOpenGuide}
                    <ArrowUpRight size={15} weight="bold" aria-hidden="true" />
                  </a>
                </aside>
              )}
              <p className="requirement">
                {isStableRelease ? t.requirement : t.betaRequirement}
              </p>
            </div>

            <div className="download-mascot" aria-hidden="true">
              <img src="/assets/clawd-update.svg" alt="" />
            </div>

            <ul className="safeguards">
              {(isStableRelease ? t.safeguards : t.betaSafeguards).map((item) => (
                <li key={item}>
                  <Check size={18} weight="bold" aria-hidden="true" />
                  {item}
                </li>
              ))}
            </ul>
          </section>
        </main>

        <footer className="footer">
          <div className="footer-brand">
            <img src="/assets/app-icon.svg" alt="" />
            <strong>CLAUDE_ISLAND</strong>
          </div>
          <p>{t.legal}</p>
          <div className="footer-links">
            <span>
              {t.creator}{" "}
              <a href="https://x.com/686f6c61">686f6c61</a>
            </span>
            <a
              className="footer-social"
              href="https://x.com/686f6c61"
              aria-label="X / Twitter: @686f6c61"
            >
              <XLogo size={15} weight="bold" aria-hidden="true" />
              <span>@686f6c61</span>
            </a>
            <a href={`${REPOSITORY}/blob/main/LICENSE`}>License</a>
            <a href={`${REPOSITORY}/blob/main/SECURITY.md`}>Security</a>
          </div>
        </footer>
      </div>
    </>
  );
}
