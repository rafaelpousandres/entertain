// Spec 029 — pure-logic tests for the RSVP page (run with `deno test`). Covers
// language selection, date-only expiry, HTML escaping, checkbox parsing, and the
// privacy/branch behaviour of the rendered pages. The DB/serve wiring in
// index.ts is validated end-to-end.

import {
  assert,
  assertEquals,
  assertStringIncludes,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  checked,
  escapeHtml,
  isExpired,
  pickLang,
  renderExpired,
  renderNotFound,
  renderPage,
} from "./lib.ts";

Deno.test("pickLang ships ca/es/en, falls back to ca", () => {
  assertEquals(pickLang("es"), "es");
  assertEquals(pickLang("en"), "en");
  assertEquals(pickLang("ca"), "ca");
  assertEquals(pickLang("fr"), "ca");
  assertEquals(pickLang(null), "ca");
});

Deno.test("escapeHtml neutralises injection", () => {
  assertEquals(
    escapeHtml(`<script>"&'`),
    "&lt;script&gt;&quot;&amp;&#39;",
  );
});

Deno.test("checked reads truthy checkbox values", () => {
  assert(checked("1"));
  assert(!checked(null));
  assert(!checked("0"));
});

Deno.test("isExpired is date-only (whole event day, Madrid)", () => {
  const now = new Date("2026-06-14T12:00:00Z"); // mid-day on the 14th
  assert(!isExpired("2026-06-14", now)); // event day → still open
  assert(!isExpired("2026-06-15", now)); // future → open
  assert(isExpired("2026-06-13", now)); // past day → expired
  assert(!isExpired(null, now)); // undated → never expires
});

Deno.test("renderPage shows only name + title; escapes; no event details", () => {
  const html = renderPage({
    lang: "ca",
    token: "tok-123",
    name: "<Anna>",
    title: "Sopar d'estiu",
    state: "pendent",
    diet: { vegetarian: false, vegan: false, glutenFree: false },
    saved: null,
  });
  assertStringIncludes(html, "Hola &lt;Anna&gt;,"); // escaped name
  assertStringIncludes(html, "et conviden a Sopar d'estiu.");
  assertStringIncludes(html, "Hi seré");
  assertStringIncludes(html, "No podré");
  assertStringIncludes(html, 'name="diet_vegan"');
  // Privacy: the page must not leak any event detail beyond the title.
  assert(!html.includes("2026"));
  assert(!html.toLowerCase().includes("carrer"));
  assert(!html.toLowerCase().includes("location"));
});

Deno.test("renderPage reflects current answer + diet (checkboxes pre-checked)", () => {
  const html = renderPage({
    lang: "ca",
    token: "t",
    name: "Pau",
    title: "Festa",
    state: "confirmat",
    diet: { vegetarian: false, vegan: true, glutenFree: true },
    saved: "confirm",
  });
  assertStringIncludes(html, "Gràcies, hem registrat que hi seràs.");
  assertStringIncludes(html, 'name="diet_vegan" value="1" checked');
  assertStringIncludes(html, 'name="diet_gluten_free" value="1" checked');
  assert(!html.includes('name="diet_vegetarian" value="1" checked'));
});

Deno.test("not-found and expired pages leak nothing", () => {
  const nf = renderNotFound("ca");
  assertStringIncludes(nf, "Invitació no trobada.");
  assert(!nf.includes("Hola"));
  const ex = renderExpired("es");
  assertStringIncludes(ex, "Este evento ya ha pasado.");
  assert(!ex.includes("Hola"));
});
