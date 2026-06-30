#!/usr/bin/env python3
"""Regenerable photo upload for the demo dataset (group 1f09).

Uploads the versioned cover images under supabase/seed/photos/ to Storage and
upserts the matching `media` rows. Idempotent: re-running overwrites the same
Storage object (deterministic path `{entityId}/seed-cover.jpg`) and re-creates
the single seed `media` row, so the dataset's photos regenerate to a known
state. Reads the committed JPEGs — it does NOT call Pexels (that was the
one-time build), so regeneration needs no network/quota beyond Storage.

Run AFTER demo_dataset_1f09.sql (entities must exist; ids are resolved by
natural key — name/title — so it works regardless of the entities' current ids).

Needs the LEGACY service_role JWT in the environment:
    export SUPABASE_SERVICE_ROLE_KEY=eyJ...
SUPABASE_URL is read from ~/.config/entertain/local.json.

    set -a; source ~/.config/entertain/run-secrets.env; set +a
    python3 supabase/seed/upload_seed_photos.py
"""
import json, os, sys, urllib.parse, urllib.request

G = "1f09045b-cacd-449a-a8a1-c7bdfb5bdc52"
REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CFG = json.load(open(os.path.expanduser("~/.config/entertain/local.json")))
URL = CFG["SUPABASE_URL"]
KEY = os.environ["SUPABASE_SERVICE_ROLE_KEY"]
MANIFEST = os.path.join(REPO, "supabase", "seed", "photos", "manifest.json")
BUCKET = {"ingredient": "ingredient-photos", "dish": "dish-photos",
          "drink": "drink-photos", "event": "event-photos"}
# entity_type -> (REST table, natural-key column)
TABLE = {"ingredient": ("ingredients", "name"), "dish": ("dishes", "name"),
         "drink": ("drinks", "name"), "event": ("events", "title")}
HJSON = {"apikey": KEY, "Authorization": f"Bearer {KEY}", "Content-Type": "application/json"}

def req(method, path, data=None, headers=None, raw=False):
    r = urllib.request.Request(URL + path, data=data, method=method,
                               headers=headers or HJSON)
    with urllib.request.urlopen(r, timeout=60) as resp:
        body = resp.read()
        return body if raw else (json.loads(body) if body else None)

def id_map(table, keycol):
    flt = "title" if keycol == "title" else "name"
    q = f"/rest/v1/{table}?group_id=eq.{G}&select=id,{flt}"
    if table != "events":
        q += "&deleted_at=is.null"
    rows = req("GET", q)
    return {r[flt]: r["id"] for r in rows}

def main():
    manifest = json.load(open(MANIFEST))
    maps = {t: id_map(*TABLE[t]) for t in TABLE}
    ok, miss = 0, []
    for m in manifest:
        if m.get("status") != "ok":
            continue
        etype, name = m["type"], m["name"]
        eid = maps[etype].get(name)
        if not eid:
            miss.append(f"{etype}:{name} (no entity)")
            continue
        fpath = os.path.join(REPO, m["file"])
        if not os.path.exists(fpath):
            miss.append(f"{etype}:{name} (no file)")
            continue
        path = f"{eid}/seed-cover.jpg"  # deterministic per entity
        bytes_ = open(fpath, "rb").read()
        # 1. Upload (upsert) to Storage.
        req("POST", f"/storage/v1/object/{BUCKET[etype]}/{path}", data=bytes_,
            headers={"apikey": KEY, "Authorization": f"Bearer {KEY}",
                     "Content-Type": "image/jpeg", "x-upsert": "true"}, raw=True)
        # 2. Replace the seed media row (idempotent).
        pv = urllib.parse.quote(path, safe="")
        req("DELETE",
            f"/rest/v1/media?entity_type=eq.{etype}&entity_id=eq.{eid}&path=eq.{pv}",
            headers={**HJSON, "Prefer": "return=minimal"}, raw=True)
        req("POST", "/rest/v1/media",
            data=json.dumps({
                "entity_type": etype, "entity_id": eid, "path": path, "position": 0,
                "source_provider": "pexels", "source_author": m.get("author"),
                "source_url": m.get("url"),
                "source_ref": str(m["pexels_id"]) if m.get("pexels_id") else None,
            }).encode(),
            headers={**HJSON, "Prefer": "return=minimal"}, raw=True)
        ok += 1
        print(f"[{ok}] {etype}:{name} -> {BUCKET[etype]}/{path}", file=sys.stderr)
    print(f"\n# DONE: {ok} uploaded. {len(miss)} skipped." +
          ("" if not miss else " SKIPPED: " + ", ".join(miss)), file=sys.stderr)

if __name__ == "__main__":
    main()
