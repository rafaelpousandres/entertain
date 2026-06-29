# CLAUDE.md — entertain

> Operational document for this repository. Claude Code reads it every session.
> Version 0.1.
> Defines the working rules, the stack, and the non-negotiable norms of the
> `entertain` project. Product decisions and technical detail live in the
> documents referenced under "Project documents".

---

## What entertain is

A mobile app for organizing domestic events (lunches and dinners for many
guests): menus, dishes, ingredients, and per-supplier shopping lists sent over
WhatsApp. A single product; this repository is exclusive to this app.

---

## Roles

- **claude.ai** is the management and decision hub: it plans, makes all product,
  design, and architecture decisions, and produces the documents (plan,
  specifications, mockups).
- **Claude Code** (you, in this repository) is the executor: writes the code,
  operates the terminal, sets up the project, builds, and tests.
- **The bridge between the two is the set of versioned documents in the
  repository.** Claude Code works from these files. Do not improvise product or
  architecture decisions here: if a specification is unclear or looks
  incomplete, stop and flag it so it can be resolved on claude.ai.
- **The user** (Rafael Pous) directs the project, makes the important
  decisions, acts as QA by testing the app, and operates the accounts. He does
  not review code line by line.

---

## Working cycle

For each feature or phase: a clear specification is prepared on claude.ai →
Claude Code implements it on a feature branch → the user tests and validates →
back to claude.ai for the next one. Work only on the current specification; do
not pull scope forward from future phases.

---

## Working method with Claude Code (v0.6)

- **Broad prompts, not atomic instructions.** You receive complete objectives
  with their acceptance criteria and do all the low-level work yourself
  (diagnosis, checks, edits, tests, build) without going step by step. At the
  end you **report in detail** what you did and what you decided.
- **The user is a light bridge.** He relays the prompt in and your **final
  report** back — not intermediate terminal output. Minimize the number of
  cycles and hand-run commands.
- **Technical decisions → Claude Code; product decisions → claude.ai.** Resolve
  every technical question (how to implement, which structure, which migration,
  which pattern) yourself. Only escalate product, design, or scope decisions —
  and even minor ones you may settle, leaving a record.
- **Ask in plain text.** When you need to ask or present options, write them as
  text in your reply (with pros/cons and a recommendation), never as interactive
  selectors, so the user can copy them.
- **Explicit stop points.** Stop when (a) a new product/design/scope decision
  appears, or (b) before an irreversible data operation (see below). To review a
  plan before building, the prompt must explicitly say so — plan mode alone is
  not enough.
- **Permission allowlist.** Permissions follow an allowlist (`settings.json`):
  **allow** reads, code edits, and routine commands (read-only git, commit, PR,
  build, test); **ask** for destructive or publishing operations (Supabase
  migration push / `db push`, Edge Function deploy, `git push`, `reset --hard`);
  **deny** for the irreversible (`rm -rf`, reading secrets, `push --force`).
  Security rules (ask/deny) live at user level (`~/.claude/settings.json`); the
  stack tools live at project level.
- **Migrations: the user confirms the "what and where", not the SQL.** You
  validate each migration's technical correctness yourself. Before pushing a
  migration, **explain in words** what it does (what it creates/alters/drops, on
  which database, whether it touches existing data or only structure) and stop
  for the user to confirm. The user decides by the explained consequence, not by
  reading the SQL — critical wherever there is real production data.
- **Query audit before production.** Before each step to production — and
  whenever you notice slowness or touch critical queries — audit the queries:
  static (code review: N+1, heavy selects, missing indexes) and, if needed,
  dynamic (real performance). Part of "do it right, no shortcuts".

> **Full conventions:** `rafaelpousandres/apps-and-webs-docs` ›
> `Convencions de desenvolupament.md` (v0.8). This `CLAUDE.md` is an operational
> extract adapted to `entertain`; do not duplicate the canonical document here.

---

## Non-negotiable rules

These rules cannot be relaxed without first updating the canonical conventions
document.

- **Secrets out of the code.** No API key, credential, or secret in the code or
  in the repository. They live in environment files excluded via `.gitignore`,
  in Supabase configuration, and in CI secrets. Any third-party API is called
  from a server-side proxy (Edge Function), never directly from the client.
- **Edge Functions need explicit `service_role` grants.** Any table an Edge
  Function reads or writes with the service-role client needs an explicit GRANT
  to `service_role` (SELECT and/or DML per the use). `service_role` has
  BYPASSRLS, but Postgres checks table privileges *before* RLS — so a missing
  grant fails with "permission denied for table …", which the client often
  swallows into a silent fallback (wrong limit, `no_units`, etc.). The 019/020
  grants were made only to `anon`/`authenticated`; every new table a function
  touches must include the `service_role` grant **in its initial migration**.
  Never swallow the error on these service-role reads — log it (`console.error`)
  so the next gap surfaces loudly. (This pattern bit us four times in one
  session: media, translations, quota_entitlements/quota_usage, units/
  supplier_categories.)
- **Lesson transfer: complete or not done.** When a reusable integration or
  architecture lesson is captured on one project, in the SAME pass (not
  "later"): (1) write it to the cross-project lessons document
  (`herencia-talaia.md`, in the `apps-and-webs-docs` repo); (2) propagate and
  apply it to the other projects on the same stack hit by the same problem; and
  (3) if the lesson implies a verifiable invariant, turn it into an executable
  check (a test or a fail-closed assertion), not a note. A lesson that lives
  only as prose is not learned. A known, un-propagated lesson is a known hole
  left open across the rest of the projects.
- **Data in the EU.** The backend (Supabase) is in an EU region. GDPR-conscious
  design: data minimization, privacy policy, store-required disclosures.
- **Internationalization from day one.** Every user-visible string goes through
  i18n (intl + ARB files). Base languages: Catalan, Spanish, English. No string
  literals hardcoded in the code.
- **Full data model from the start.** The data model is designed for the
  complete vision; phases activate subsets of it and do not redesign it. Do not
  modify it on your own: structural changes are decided on claude.ai and
  reflected in the data model document.
- **Main branch always shippable.** Work on feature branches with pull
  requests. CI runs automated tests and dependency checks. Nothing is merged
  that leaves `main` in a non-shippable state.
- **Lean first.** Each phase is a coherent, usable, shippable release.
  Implement the minimal scope of the current specification; do not add
  unrequested functionality.

---

## Tech stack

> **Flutter is a deliberate legacy exception, not the project default.** Per the
> Development conventions (§4, v0.2), new serious platforms (Talaia, Helm) use the
> unified TypeScript stack (React + React Native + NestJS). Entertain stays on
> Flutter and **is not migrated** — this is a settled decision, not a pending task.

- **Framework:** Flutter (Dart), a single codebase for Android and iOS.
- **Backend:** Supabase — PostgreSQL, Auth, Storage, Edge Functions; EU region.
- **Authentication:** anonymous first, upgradable to a real account with no
  migration.
- **State management:** Riverpod.
- **Navigation:** go_router.
- **i18n:** intl + ARB files.
- **Maps:** Google Maps (`google_maps_flutter`).
- **Media:** device camera/gallery + Supabase Storage.
- **Visual base:** Material 3, with the project's own design system.
- **CI:** GitHub Actions.
- **Builds and release:** Codemagic.
- **Error monitoring:** Sentry, configured not to collect personal data.

---

## Version control

- One repository per product; this is the `entertain` one.
- Work on feature branches; integration into `main` via pull request.
- Semantic versioning; every released version is tagged.
- Environment files with secrets and build artifacts are excluded via
  `.gitignore`.

---

## Release

Android first, iOS later (iOS is a later phase). Play Store tracks: internal
testing → closed testing → production.

**Mobile validation gate (pre-merge).** For Entertain the merge gate is **not**
green CI alone: on-device validation is **pre-merge**. The flow per pass is:
code on a feature branch → green CI → **build the AAB from that branch** (see the
output convention below) → validate on the Pixel via the Play Console **internal
testing** channel (not in local) → **squash-merge to `main` only once the
validation passes**. If the validation fails, fix it **on the branch** and
rebuild — never patch `main`. `main` never receives code that has not been
validated on the device. (Canonical: `Convencions de desenvolupament` §2.3, v0.9.)

**Release AAB output convention (permanent rule).** After every
`flutter build appbundle --release` (always with
`--dart-define-from-file="$HOME/.config/entertain/local.json"`), do not leave the
artifact at the default build path. **Copy** the generated
`build/app/outputs/bundle/release/app-release.aab` to the Windows tray with a
**versioned name**:

- Location: `/mnt/c/Users/rafa/Claude/entertain/` (the Windows tray —
  `C:\Users\rafa\Claude\entertain\`).
- Name: `entertain-<version>+<versionCode>.aab` — i.e. `<build-name>+<build-number>`
  from `pubspec.yaml` (e.g. `entertain-1.0.27+39.aab`).

The AAB is a build **output** handed to the user for upload to the Play Console;
this does not make Windows a source of truth (the canonical repo stays on Linux).
Report the final tray path + version + versionCode after each build.

---

## Project documents

Detail not covered in this file lives in these documents (in the repository or
managed on claude.ai). When in doubt, consult them; do not improvise.

- **Development plan** — vision, phases, and scope of each phase.
- **Data model** — full schema for the complete vision.
- **Design system** — colors, typography, components, UI patterns.
- **Development conventions** — canonical reusable document (v0.8),
    `rafaelpousandres/apps-and-webs-docs` › `Convencions de desenvolupament.md`;
    this `CLAUDE.md` is an operational extract of it adapted to `entertain`.
- **Specifications** — the concrete brief for each feature or phase.

---

## Repository data

- GitHub owner: `rafaelpousandres`
- Repository: `https://github.com/rafaelpousandres/entertain` (private)
- Development environment: WSL2 (Ubuntu) on Windows; the code lives on the
  Linux filesystem.
- **Single canonical repo: `~/claude/entertain` (Linux/WSL).** The Windows
  folder `C:\Users\rafa\Claude\entertain` (`/mnt/c/...`) is **NOT a checkout**:
  it is only a tray where the browser downloads files generated on claude.ai
  (aab, md, pdf, png). **Rule:** any file downloaded on Windows that must become
  part of the repo, copy it into the canonical Linux repo **first**, before any
  commit. **Windows is never the source of truth.**

## House rules
- Specs and project documents live under docs/. Always read the relevant
  spec or document file before working; never work from pasted text.
- One feature branch + PR per spec, phase, or docs pass; commit the spec
  together with the code that implements it.
- claude.ai → repo file bridge (§2.5 v0.7). Documents authored on claude.ai are
  downloaded to `C:\Users\rafa\Claude\<folder>\` (WSL:
  `/mnt/c/Users/rafa/Claude/<folder>/`), where `<folder>` is `entertain`,
  `talaia`, or `helm` per project, and `docs` for documents bound for the shared
  `apps-and-webs-docs` repo. To incorporate a file, claude.ai hands Claude Code
  only the final objective (which file, its destination in the repo, the commit
  message); Claude Code then runs the whole docs/ pass alone — branch off
  up-to-date `main`, copy preserving the EXACT name (spaces and accents
  included), commit, push, open the PR, wait for CI, squash-merge if green — and
  reports. No manual git from the user. If CI goes red or anything unexpected
  happens, Claude Code stops and reports without merging.
- Work through the whole objective and report at the end; the user is a light
  bridge, not a step-by-step operator. Pause only at explicit stop points: a new
  product/design/scope decision, or before an irreversible data operation.
- Explain changes and plans in plain language; the user supervises
  architecture and product, not code lines.
- Never put keys or secrets in code, specs, or commits; environment and
  config files stay excluded via .gitignore.
- Commit small and often, with clear messages.
- Validation happens on the user's Pixel 8 Pro, and is a **pre-merge gate**
  (see Release → "Mobile validation gate"): the AAB is built from the feature
  branch and validated on the device before the squash-merge to `main`.