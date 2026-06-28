// Spec 029 — pure helpers + HTML rendering for the public RSVP page. Kept apart
// from index.ts (which calls Deno.serve + Supabase) so `deno test` can import
// these without starting a server or touching the DB.

export type Lang = "ca" | "es" | "en";

/** The page language: the `lang` query param when it is one we ship, else ca. */
export function pickLang(v: string | null | undefined): Lang {
  return v === "es" || v === "en" || v === "ca" ? v : "ca";
}

/** HTML-escape untrusted text (guest name, event title) before interpolation. */
export function escapeHtml(s: string): string {
  return s
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

/** Today's calendar date (YYYY-MM-DD) in Europe/Madrid — the app treats event
 * dates as local wall-clock, and this keeps the day boundary correct. */
export function todayInMadrid(now: Date): string {
  return new Intl.DateTimeFormat("en-CA", {
    timeZone: "Europe/Madrid",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(now);
}

/** Date-only expiry (Spec 029, chosen): the link works the whole event day and
 * expires the next midnight. An undated event never expires. Both sides are
 * "YYYY-MM-DD" so a lexicographic compare is a date compare. */
export function isExpired(eventDate: string | null | undefined, now: Date): boolean {
  if (!eventDate) return false;
  return eventDate < todayInMadrid(now);
}

export type Choice = "confirm" | "decline";

/** A truthy checkbox value from the POST form ("1" when checked, absent else). */
export function checked(v: FormDataEntryValue | null): boolean {
  return v === "1" || v === "on" || v === "true";
}

export interface Diet {
  vegetarian: boolean;
  vegan: boolean;
  glutenFree: boolean;
}

interface Strings {
  htmlTitle: string;
  greeting: (name: string) => string;
  invite: (title: string) => string;
  question: string;
  confirm: string;
  decline: string;
  dietLegend: string;
  vegetarian: string;
  vegan: string;
  glutenFree: string;
  currentConfirmed: string;
  currentDeclined: string;
  savedConfirmed: string;
  savedDeclined: string;
  expired: string;
  notFound: string;
}

// ca/es/en, mirroring the app's wording (guest states + invitation tone).
const STRINGS: Record<Lang, Strings> = {
  ca: {
    htmlTitle: "Invitació",
    greeting: (n) => `Hola ${n},`,
    invite: (t) => `et conviden a ${t}.`,
    question: "Podràs venir-hi?",
    confirm: "Hi seré",
    decline: "No podré",
    dietLegend: "Tens alguna restricció alimentària? (opcional)",
    vegetarian: "Vegetarià",
    vegan: "Vegà",
    glutenFree: "Sense gluten",
    currentConfirmed: "La teva resposta: hi seràs.",
    currentDeclined: "La teva resposta: no podràs venir-hi.",
    savedConfirmed: "Gràcies, hem registrat que hi seràs.",
    savedDeclined: "Gràcies, hem registrat que no podràs venir-hi.",
    expired: "Aquest esdeveniment ja ha passat.",
    notFound: "Invitació no trobada.",
  },
  es: {
    htmlTitle: "Invitación",
    greeting: (n) => `Hola ${n},`,
    invite: (t) => `te invitan a ${t}.`,
    question: "¿Podrás venir?",
    confirm: "Allí estaré",
    decline: "No podré",
    dietLegend: "¿Tienes alguna restricción alimentaria? (opcional)",
    vegetarian: "Vegetariano",
    vegan: "Vegano",
    glutenFree: "Sin gluten",
    currentConfirmed: "Tu respuesta: allí estarás.",
    currentDeclined: "Tu respuesta: no podrás venir.",
    savedConfirmed: "Gracias, hemos registrado que vendrás.",
    savedDeclined: "Gracias, hemos registrado que no podrás venir.",
    expired: "Este evento ya ha pasado.",
    notFound: "Invitación no encontrada.",
  },
  en: {
    htmlTitle: "Invitation",
    greeting: (n) => `Hi ${n},`,
    invite: (t) => `you're invited to ${t}.`,
    question: "Will you make it?",
    confirm: "I'll be there",
    decline: "I can't",
    dietLegend: "Any dietary restrictions? (optional)",
    vegetarian: "Vegetarian",
    vegan: "Vegan",
    glutenFree: "Gluten-free",
    currentConfirmed: "Your answer: you'll be there.",
    currentDeclined: "Your answer: you can't come.",
    savedConfirmed: "Thanks — we've noted that you'll be there.",
    savedDeclined: "Thanks — we've noted that you can't come.",
    expired: "This event has already taken place.",
    notFound: "Invitation not found.",
  },
};

// Entertain palette (matches the app): cream bg, brand green, terracotta accent.
const STYLE = `
  :root{color-scheme:light}
  *{box-sizing:border-box}
  body{margin:0;background:#FBF5EA;color:#412402;
    font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif;
    display:flex;min-height:100vh;align-items:center;justify-content:center;padding:24px}
  .card{background:#fff;border:1px solid #EDE2CC;border-radius:18px;
    max-width:420px;width:100%;padding:28px 24px;text-align:center}
  .brand{font-weight:800;font-size:20px;color:#1F6B52;letter-spacing:.2px;margin-bottom:18px}
  h1{font-size:22px;font-weight:700;margin:0 0 6px}
  .invite{font-size:18px;margin:0 0 18px;color:#412402}
  .q{color:#8A7256;margin:0 0 14px}
  .banner{background:#E1F5EE;color:#0F6E56;border-radius:12px;padding:10px 12px;margin:0 0 16px;font-weight:600}
  .answers{display:flex;gap:10px;margin:6px 0 18px}
  button{flex:1;border:0;border-radius:12px;padding:13px 10px;font-size:16px;font-weight:700;cursor:pointer}
  .confirm{background:#1F6B52;color:#fff}
  .decline{background:#D85A30;color:#fff}
  .ghost{background:#fff;border:1px solid #EDE2CC;color:#8A7256}
  fieldset{border:1px solid #EDE2CC;border-radius:12px;text-align:left;margin:0;padding:12px 14px}
  legend{color:#8A7256;font-size:13px;padding:0 6px}
  label{display:flex;align-items:center;gap:10px;padding:6px 0;font-size:15px}
  input[type=checkbox]{width:18px;height:18px;accent-color:#1F6B52}
  .msg{font-size:17px;line-height:1.4}
`;

function shell(lang: Lang, inner: string): string {
  const t = STRINGS[lang];
  return `<!doctype html><html lang="${lang}"><head><meta charset="utf-8">` +
    `<meta name="viewport" content="width=device-width,initial-scale=1">` +
    `<meta name="robots" content="noindex,nofollow">` +
    `<title>${t.htmlTitle} · Entertain</title><style>${STYLE}</style></head>` +
    `<body><main class="card"><div class="brand">Entertain</div>${inner}</main></body></html>`;
}

/** Neutral "not found" — identical for unknown/mistyped/deleted tokens. */
export function renderNotFound(lang: Lang): string {
  return shell(lang, `<p class="msg">${STRINGS[lang].notFound}</p>`);
}

/** Expired — shown after the event day; no name/title, no response. */
export function renderExpired(lang: Lang): string {
  return shell(lang, `<p class="msg">${STRINGS[lang].expired}</p>`);
}

export interface PageOpts {
  lang: Lang;
  token: string;
  name: string;
  title: string;
  state: string; // 'confirmat' | 'excusat' | anything else (pending)
  diet: Diet;
  saved: Choice | null; // a banner after a POST
}

/** The RSVP page: ONLY the guest name + event title, the two answer buttons
 * (reflecting the current answer) and the 3 optional diet checkboxes — never any
 * date/place/notes or other guests. Name + title are escaped. */
export function renderPage(o: PageOpts): string {
  const t = STRINGS[o.lang];
  const confirmed = o.state === "confirmat";
  const declined = o.state === "excusat";
  const ck = (on: boolean) => (on ? " checked" : "");

  const banner = o.saved === "confirm"
    ? `<div class="banner">${t.savedConfirmed}</div>`
    : o.saved === "decline"
    ? `<div class="banner">${t.savedDeclined}</div>`
    : confirmed
    ? `<div class="banner">${t.currentConfirmed}</div>`
    : declined
    ? `<div class="banner">${t.currentDeclined}</div>`
    : "";

  return shell(
    o.lang,
    `<h1>${t.greeting(escapeHtml(o.name))}</h1>` +
      `<p class="invite">${t.invite(escapeHtml(o.title))}</p>` +
      banner +
      `<form method="POST">` +
      `<input type="hidden" name="token" value="${escapeHtml(o.token)}">` +
      `<p class="q">${t.question}</p>` +
      `<fieldset><legend>${t.dietLegend}</legend>` +
      `<label><input type="checkbox" name="diet_vegetarian" value="1"${ck(o.diet.vegetarian)}> ${t.vegetarian}</label>` +
      `<label><input type="checkbox" name="diet_vegan" value="1"${ck(o.diet.vegan)}> ${t.vegan}</label>` +
      `<label><input type="checkbox" name="diet_gluten_free" value="1"${ck(o.diet.glutenFree)}> ${t.glutenFree}</label>` +
      `</fieldset>` +
      `<div class="answers">` +
      `<button class="${confirmed ? "confirm" : "ghost"}" name="choice" value="confirm">${t.confirm}</button>` +
      `<button class="${declined ? "decline" : "ghost"}" name="choice" value="decline">${t.decline}</button>` +
      `</div>` +
      `</form>`,
  );
}
