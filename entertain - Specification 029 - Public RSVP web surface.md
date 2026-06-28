# Spec 029 — Public RSVP web surface (guests Layer 2)

Branch: one PR. **Entertain's first public web surface.** Server-side: a Supabase Edge
Function serving minimal HTML + handling the response. No new hosting/infra — stays within
the existing Supabase stack (EU region, GDPR).

## Context

Layer 1 (Spec 023) lets the host send invitations (WhatsApp/SMS/email) and **manually** set
each guest's state. Layer 2 lets the **guest respond themselves**: the invitation carries a
**unique link**; tapping it opens a tiny public web page where the guest confirms or declines.
Their answer flows back into the host's app (same Supabase) and appears on the Convidats tab.

Design principle: **minimíssim** — the page does the least that works, and exposes the least
data. Event details (when/where) travel in the **private invitation message**, not on the
public page.

## A. The unique link

- Each guest gets a **unique link** containing an unguessable **token** that identifies them,
  so responding requires no login and the host knows who answered.
- The token is per-guest (per event+guest), stored on the guest record; the link embeds it.
- The link is added to the invitation message (Layer 1 already composes WhatsApp/SMS/email
  messages — append the RSVP URL).
- **Expiry:** the link works until the event **starts** (event date/time). After that, the
  page shows a "this event has already taken place" message and offers no response.

## B. What the guest sees (minimal, privacy-first)

The public page shows the **minimum**:
- The guest's **name** ("Hola [nom],").
- The **event name** ("…et conviden a [esdeveniment].").
- A question and two actions: **Hi seré** (confirm) / **No podré** (decline).

**Never shown** on the public page: date, time, place, notes, the list of other guests, or any
third-party data. Those details live in the **private invitation message**. The public URL
exposes only the guest's own name + the event name. (GDPR minimization.)

The page is **localized**; pick the language from the event/app locale (or a `lang` param in
the link). Entertain visual identity (logo, colors) for a branded but tiny page.

## C. Responding

- Tapping **Hi seré** → sets the guest's state to **confirmat**; **No podré** → **excusat**.
  Reuses the exact guest states from Spec 023 (pendent/confirmat/excusat).
- After responding: a **simple confirmation** ("Gràcies, hem registrat que hi seràs." /
  "Gràcies, hem registrat que no podràs venir-hi.").
- **Changeable:** the guest can reopen the same link and change their answer as many times as
  needed; the **last response wins**. The page shows their current answer and lets them switch.
- The response writes to Supabase → the host sees the updated state on the **Convidats** tab
  (same data plane; no separate sync). Over-capacity note (Spec 023) updates accordingly.

## D. Implementation notes

- **Edge Function serving HTML.** A Supabase Edge Function (same pattern as the existing
  AI/backfill functions) that:
  - **GET** `/rsvp?token=…` → looks up the guest+event by token, checks expiry (event start),
    returns the minimal localized HTML page (or the expired/own-current-answer states).
  - **POST** (confirm/decline) → validates token, updates the guest state, returns the
    confirmation page. (A simple form POST or a small inline fetch — no SPA framework.)
- **Token:** add a column to the guest record (e.g. `rsvp_token uuid default gen_random_uuid()`
  unique) — generated when the guest is created / when the invitation is first sent. The link
  is `https://<edge-fn-host>/rsvp?token=<token>` (+ optional `lang`).
- **Security / RLS:** the Edge Function uses the service-role client to read/write the single
  guest row matched by token (server-side; the public never gets a Supabase key). Scope every
  read/write to **that token's guest only** — never expose other rows. (Remember the recurring
  Entertain lesson: any table the function reads/writes with the service-role client needs an
  explicit GRANT.)
- **Expiry check** is server-side against the event's start datetime.
- **App side:** Layer-1 invitation composing appends the RSVP URL to the message; ensure each
  guest has a token before composing. The Convidats tab already reflects state from the DB, so
  guest-driven changes appear with no extra work (a refresh/realtime read).
- **i18n:** the HTML page strings (greeting, question, the two buttons, the confirmations, the
  expired message) localized server-side; reuse the ca/es/en values (mirror the app's wording).

## E. Edge cases

- **Invalid/unknown token** → a neutral "invitation not found" page (no detail leaked).
- **Event already started** → "this event has already taken place"; no response accepted.
- **Guest re-opens after answering** → page shows their current answer and lets them change it.
- **Guest deleted by host** → token no longer resolves → "invitation not found".
- **No third-party data** ever rendered, regardless of state.

## Tests

- Token resolves to exactly one guest+event; unknown token → not-found page.
- GET before start → response page; GET after start → expired page.
- POST confirm → state `confirmat`; POST decline → state `excusat`; last response wins.
- Re-open shows current answer; switching updates it.
- The page never includes date/time/place/notes or other guests (privacy assertion).
- Service-role access is scoped to the token's guest only.
- Localized strings follow the chosen language.

## Verification

1. Edge Function deploys; `flutter analyze` + `flutter test` green for the app-side changes.
2. End-to-end: from the app, send an invitation to a guest → the message contains the RSVP
   link → open it in a browser (no app, logged out): shows "Hola [nom], et conviden a
   [esdeveniment]" + two buttons, **no** date/place/other guests → tap Hi seré → confirmation
   → the host's Convidats tab shows that guest as **confirmat** → reopen the link, switch to
   No podré → tab updates to **excusat**. After the event start time, the link shows expired.
3. Privacy check: the page source exposes only the guest's name + event name.

## Out of scope

- Guest messages, +N companions, dietary input (kept minimíssim — future Layer 3 if ever).
- Any login/account for guests.
- A full web frontend / SPA (an Edge-Function HTML page is enough).
- Push/realtime niceties beyond the host seeing the updated state on a normal read.
- Changing Layer-1 invitation channels (still WhatsApp/SMS/email).
