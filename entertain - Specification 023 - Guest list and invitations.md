# Specification 023 — Guest list & invitations (with optional RSVP link)

> Build assignment for Claude Code. Read CLAUDE.md, "entertain - Data model.md",
> and the backlog (§1B Convidats i esdeveniment social). Reuses the existing
> **supplier contacts pattern** (phone/email + device-contacts access) and the
> **order-message pattern** (generate text, user sends via their own channel).
>
> Specified in **two layers**: Layer 1 (core — list + manual states + send
> invitation text) is implementable on its own; Layer 2 (RSVP link — public
> landing + endpoint) is a later pass. Build **Layer 1 first**; Layer 2 when
> chosen. Migration/Edge-Function shown before push/deploy. Branch:
> `feat/spec-023-guest-list`.

---

## Layer 1 — Guest list + manual states + invitation text  (build first)

### 1.1 New "Convidats" tab in an Event
A new tab in the Event screen: **"Convidats"** (alongside Menú etc.).

### 1.2 Add guests — form + device contacts
Two ways to add a guest (reuse the **supplier** contact pattern that already does
this):
- **Form:** name + phone + email (name required; phone/email optional but at
  least one needed to send an invitation).
- **From device contacts:** pick from the phone's contacts (same plugin/permission
  flow as suppliers). Map contact name/phone/email into the guest.

### 1.3 Guest fields & state
Per guest: **name**, **phone**, **email**, **state** ∈ {**pendent**, **confirmat**,
**excusat**}. State is **freely editable** by the host at any time (tap to change).
Default state on add = **pendent**.

### 1.4 List view — grouped by state, accordion, totals
- Guests **grouped by state**, each group an **accordion** (collapsible) section:
  Pendents / Confirmats / Excusats.
- **Per-group subtotal** shown on each group header.
- **Grand total** shown at the top (total guests).
- (Tap a guest → edit form; change state; delete.)

### 1.5 Over-capacity notice
The guest list is **independent** from the event's people count (which drives
servings/shopping) — confirmed guests do NOT auto-set it (the list keeps
changing). But show a **notice/badge** when **# confirmats > event people count**
("Tens més confirmats que comensals previstos") so the host can adjust the event
if they want. Informational only; doesn't change the servings math.

### 1.6 Invitation text (event-level, prefilled & editable)
- At **event level**, an **invitation message**: auto-**prefilled** from the event
  data (name, date, place if present) but **editable** by the host (like a
  template they can tweak once for the event).
- **Sending** (per guest, like the supplier order message): a **send** action on
  a guest builds the invitation and hands it to the user's own channel —
  **WhatsApp/SMS** if the guest has a phone, **email** if they have an email
  (offer the available channel(s); the app composes, the user sends). No
  automatic sending from the app.
- Optional: mark a guest as "invitat" (invitation sent) — a simple boolean/
  timestamp, separate from RSVP state, so the host tracks who's been contacted.

### 1.7 Layer-1 model (migration)
```sql
create table public.event_guests (
  id          uuid primary key default gen_random_uuid(),
  event_id    uuid not null references public.events(id) on delete cascade,
  group_id    uuid not null references public.groups(id) on delete cascade,
  name        text not null,
  phone       text,
  email       text,
  state       text not null default 'pendent'
              check (state in ('pendent','confirmat','excusat')),
  invited_at  timestamptz,            -- set when invitation sent (1.6)
  created_at  timestamptz not null default now()
);
alter table public.event_guests enable row level security;
create policy event_guests_rw on public.event_guests
  for all to authenticated
  using (public.is_group_member(group_id))
  with check (public.is_group_member(group_id));
grant select, insert, update, delete on table public.event_guests
  to anon, authenticated;
-- invitation template on the event:
alter table public.events add column if not exists invitation_text text;
```
- House rule: if a Layer-2 Edge Function later reads/writes these with the
  service role, add explicit `service_role` grants then.

---

## Layer 2 — RSVP via link  (later pass; specified, not built first)

Goal: each guest gets a **personal link**; clicking **Confirmo / No puc** updates
their state automatically — no app install, no login for the guest.

Pieces required (this is the project's **first public web surface**, hence its own
layer):
- **Per-guest token:** a unique, unguessable token per guest (e.g. `rsvp_token`
  uuid column on `event_guests`), embedded in the link. The token identifies the
  guest; it grants **only** the ability to set that guest's RSVP state — nothing
  else.
- **Public landing page:** a minimal web page (event name/date + two buttons:
  Confirmo / No puc / maybe "Potser"). Lives outside the app. Decide hosting
  (static page calling the endpoint, or the endpoint renders it). Must be
  EU-hosted (GDPR), no tracking.
- **Endpoint (Edge Function `rsvp`):** receives the token + chosen response →
  validates token → updates that guest's `state`. Service-role write → **explicit
  grant** on `event_guests`. Rate-limit / validate to prevent abuse.
- **Invitation text gains the link:** when Layer 2 is on, the generated invitation
  (1.6) includes the guest's personal RSVP link.
- **Host view:** RSVP responses flow into the same accordion/totals (Layer 1 UI)
  automatically — confirmat/excusat now arrive from guests, not only manual.

Security/privacy: token is capability-scoped (only that guest's RSVP); no PII
beyond the event name on the landing; GDPR (third-party contact data, consent,
minimization, EU hosting). Tokens revocable (rotate/clear).

**Decision deferred to Layer-2 build:** hosting of the landing page (static vs
function-rendered), and whether to add a "Potser/Tentative" state then.

---

## i18n, tests, verification
- i18n ca/es/en: tab name, state labels, group headers, totals, add-form,
  contacts-picker strings, over-capacity notice, invitation compose/send,
  (Layer 2) landing + buttons. `flutter gen-l10n`.
- Tests (Layer 1): add guest (form + contacts mock); state change; grouping +
  subtotals + grand total; over-capacity notice fires when confirmats > people;
  invitation text prefilled from event + editable; send builds correct
  channel(s). Keep suite green.
- `flutter analyze` + `flutter test` green before PR.

### Operator / deploy
- Layer 1: `supabase db push` (event_guests + events.invitation_text), shown
  before push. No Edge Function needed for Layer 1.
- Layer 2 (later): `rsvp` Edge Function deploy + token column migration + landing
  hosting.
- On device (Layer 1): add guests via form and contacts; group/accordion/totals
  correct; edit states freely; over-capacity notice; edit invitation text; send
  to a guest opens WhatsApp/SMS/email with the message.

## Out of scope (this spec)
- Connecting confirmed count to the event's servings/shopping (kept independent
  by decision; only the notice).
- Guest +1s / party size per guest (could be a later refinement).
- Calendar integration / reminders.

## Notes
- Reuses supplier contacts (add) and order-message (send) patterns — don't
  reinvent; share where sensible.
- Layer 2 is the first public web surface for the project — treat its security
  (token scope) carefully when built.
