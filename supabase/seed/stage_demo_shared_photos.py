#!/usr/bin/env python3
"""Spec 033 §A.3 — stage the shared read-only demo photos.

Copies every photo of the demo TEMPLATE group (1f09…) to a shared `demo/`
prefix inside the same per-type bucket, keyed by the template MEDIA ROW id:

    {bucket}/{templatePath}          ->  {bucket}/demo/{mediaId}.jpg

`seed_demo` then makes every new user's demo `media` rows reference these shared
blobs (path `demo/{mediaId}.jpg`) instead of copying files per user — so seeding
is pure SQL and Storage stays flat no matter how many users sign up. The M4
migration opens read of `demo/%` to any authenticated user; there is no write
policy, so the shared assets are read-only and users stay isolated.

Idempotent: re-running overwrites the same destination objects (x-upsert). Reads
the template's CURRENT Storage blobs (not the repo), so it also covers photos a
human added in-app that were never versioned under supabase/seed/photos/.

Needs the LEGACY service_role JWT in the environment:
    export SUPABASE_SERVICE_ROLE_KEY=eyJ...
SUPABASE_URL is read from ~/.config/entertain/local.json.

    set -a; source ~/.config/entertain/run-secrets.env; set +a
    python3 supabase/seed/stage_demo_shared_photos.py
"""
import json, os, sys, urllib.parse, urllib.request

G = "1f09045b-cacd-449a-a8a1-c7bdfb5bdc52"
CFG = json.load(open(os.path.expanduser("~/.config/entertain/local.json")))
URL = CFG["SUPABASE_URL"]
KEY = os.environ["SUPABASE_SERVICE_ROLE_KEY"]
H = {"apikey": KEY, "Authorization": f"Bearer {KEY}"}

# entity_type -> (REST table, soft-deletable, bucket)
TYPES = {
    "ingredient": ("ingredients", True,  "ingredient-photos"),
    "dish":       ("dishes",      True,  "dish-photos"),
    "drink":      ("drinks",      False, "drink-photos"),
    "event":      ("events",      True,  "event-photos"),
}


def req(method, path, data=None, headers=None, raw=False):
    r = urllib.request.Request(URL + path, data=data, method=method,
                               headers=headers or H)
    with urllib.request.urlopen(r, timeout=120) as resp:
        body = resp.read()
        return body if raw else (json.loads(body) if body else None)


def entity_ids(table, soft):
    q = f"/rest/v1/{table}?group_id=eq.{G}&select=id"
    if soft:
        q += "&deleted_at=is.null"
    return [row["id"] for row in req("GET", q)]


def media_rows(etype, ids):
    if not ids:
        return []
    inlist = ",".join(ids)
    q = (f"/rest/v1/media?entity_type=eq.{etype}"
         f"&entity_id=in.({inlist})&select=id,entity_id,path")
    return req("GET", q)


def main():
    ok, fail = 0, []
    for etype, (table, soft, bucket) in TYPES.items():
        ids = entity_ids(table, soft)
        rows = media_rows(etype, ids)
        for m in rows:
            src = f"/storage/v1/object/{bucket}/{urllib.parse.quote(m['path'])}"
            dst_key = f"demo/{m['id']}.jpg"
            dst = f"/storage/v1/object/{bucket}/{dst_key}"
            try:
                blob = req("GET", src, raw=True)
                req("POST", dst, data=blob,
                    headers={**H, "Content-Type": "image/jpeg", "x-upsert": "true"},
                    raw=True)
                ok += 1
                print(f"[{ok}] {bucket}/{m['path']} -> {bucket}/{dst_key}",
                      file=sys.stderr)
            except Exception as e:
                fail.append(f"{etype}:{m['id']} ({e})")
    print(f"\n# DONE: {ok} staged, {len(fail)} failed."
          + ("" if not fail else " FAILED: " + ", ".join(fail)), file=sys.stderr)


if __name__ == "__main__":
    main()
