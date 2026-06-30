# tools/docgen — Entertain user documentation (PDF)

Single generator for **all** of Entertain's distributable PDF documents. One run
produces **4 documents × 3 languages = 12 PDFs**:

| Document | EN | CA | ES |
|---|---|---|---|
| Teaser (IG/FB flyer) | ✓ | ✓ | ✓ |
| Getting started guide | ✓ | ✓ | ✓ |
| User manual | ✓ | ✓ | ✓ |
| Tester guide | ✓ | ✓ | ✓ |

This replaces the older single-document, English-only generators
(`tools/build_guide.py` + `tools/build_manual.py`), which were removed — there is
**one** generator, not two parallel ones.

## Regenerate the 12 PDFs

```bash
pip install reportlab pillow          # one-time
cd tools/docgen
python3 render.py
```

The PDFs are written to `tools/docgen/out/` (git-ignored — regenerable
artifacts, not versioned). Each file is named
`Entertain - <localised title> (EN|CA|ES).pdf`.

## Layout

```
tools/docgen/
├── render.py                 # the renderer (reportlab + pillow); run this
├── content.py                # TAGLINE, VERSION, STARTER (getting-started copy)
├── content_manual_en.py      # MANUAL (English master)
├── content_manual_caes.py    # MANUAL_CA, MANUAL_ES (Catalan + Spanish manual)
├── content_teaser_tester.py  # TEASER + TESTER copy (all 3 langs)
├── assets/
│   ├── logo.png              # Entertain logo
│   └── shots/                # in-app screenshots embedded in the docs
└── out/                      # generated PDFs (git-ignored)
```

All copy lives in the `content*.py` modules — edit those to change wording, then
re-run. To bump the version stamp on every document, change `VERSION` in
`content.py`.

## Screenshots

`assets/shots/` holds the **11 screenshots the documents actually use**
(`render.py` references them by filename). Three further screenshots were
captured but are not referenced by any current document, so they are not
versioned here: `catalog_drinks`, `splash`, `settings_help`. If a future doc
section needs one of them, add the PNG to `assets/shots/` and reference it from
`render.py`.

To refresh a screenshot, replace the PNG in `assets/shots/` (keep the same
filename) and re-run.

## Relationship to the web manual

The **authoritative** manual content (including Catalan and Spanish) now lives in
these Python modules. The **web** manual at [`docs/manual/index.md`](../../docs/manual/index.md)
(served by GitHub Pages) is a separate English-Markdown copy and is **not**
generated from here. Keeping these single-sourced is tracked as conscious debt in
[`docs/backlog.md`](../../docs/backlog.md); until it's resolved, a manual content
change must be applied in both places.
