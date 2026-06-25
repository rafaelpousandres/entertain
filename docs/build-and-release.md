# Build & release — procés canònic (Android / Play Store)

> Document operatiu. **Qualsevol sessió que generi un AAB ha de seguir aquests
> passos exactament.** S'ha escrit perquè cap build futura torni a ometre les
> credencials ni repeteixi un `versionCode` (els dos errors que ja han passat).
> No conté cap clau ni secret.

---

## 0. TL;DR (la comanda que no s'ha d'oblidar)

```bash
flutter build appbundle --release \
  --dart-define-from-file="$HOME/.config/entertain/local.json"
```

⚠️ **Sense `--dart-define-from-file` l'AAB es construeix SENSE credencials.**
`SUPABASE_URL` i `SUPABASE_ANON_KEY` queden buides → `Env.hasSupabase == false`
→ l'app **no connecta** i mostra **"Invalid API key"**. Un AAB així és inservible
i, si s'ha pujat, **gasta un `versionCode`** (que ja no es pot reutilitzar). No
construeixis mai l'AAB de release sense aquest flag.

---

## 1. Fitxer de dart-defines (credencials)

Les credencials **mai** són al repositori. Viuen en un JSON fora del codi,
injectat en temps de compilació via `--dart-define-from-file` i llegit per
[lib/config/env.dart](../lib/config/env.dart) (`String.fromEnvironment`).

- **Ruta canònica:** `~/.config/entertain/local.json` (és a dir
  `$HOME/.config/entertain/local.json`).
- **Gitignored / fora del repo.** Alternativa admesa: `env/local.json` (també
  ignorada), però la ubicació activa és la de `~/.config`.
- **Claus que conté:** `SUPABASE_URL` i `SUPABASE_ANON_KEY` (l'`anon public`,
  **mai** el `service_role`).
- **Plantilla documentada:** [env/local.example.json](../env/local.example.json)
  (mostra l'estructura sense valors reals).

Comprovació ràpida (sense exposar valors):

```bash
python3 -c "import json;d=json.load(open('$HOME/.config/entertain/local.json'));\
print('keys:', sorted(d.keys()), '| url:', bool(d.get('SUPABASE_URL')), \
'| anon:', bool(d.get('SUPABASE_ANON_KEY')))"
```

Detall complet a [README.md](../README.md) §Environment.

---

## 2. Bump de versió (`pubspec.yaml`)

La línia de versió té el format `version: <versionName>+<versionCode>`:

```yaml
version: 1.0.18+21
#        └name─┘ └code┘
```

- **`versionCode` (el `+N`) ha de pujar cada AAB que es pugi a Play.**
  Google Play **rebutja `versionCode` repetits**. (Lliçó real: el `+20` es va
  pujar trencat; per repujar va caldre saltar a `+21` — un code cremat no torna.)
- El `versionName` (1.0.18) només canvia quan vols una etiqueta de versió nova
  visible; pot quedar igual entre builds que només pugen el `code`.
- Edita la línia a [pubspec.yaml](../pubspec.yaml) abans de construir.

---

## 3. Construir l'AAB

Des de l'arrel del repo, amb la branca correcta i el treball ja validat:

```bash
flutter build appbundle --release \
  --dart-define-from-file="$HOME/.config/entertain/local.json"
```

Sortida: `build/app/outputs/bundle/release/app-release.aab`.
Els warnings de KGP (Kotlin Gradle Plugin) i de tree-shaking de fonts són
habituals i inofensius.

Recomanat abans de construir: `flutter analyze` i `flutter test` verds.

---

## 4. Copiar l'AAB on es puja

Es copia a la carpeta compartida amb Windows, amb el nom `entertain-<name>+<code>.aab`:

```bash
cp build/app/outputs/bundle/release/app-release.aab \
   "/mnt/c/Users/rafa/Claude/entertain/entertain-1.0.18+21.aab"
```

- **Carpeta de pujada:** `/mnt/c/Users/rafa/Claude/entertain/`
- Convenció de nom: `entertain-<versionName>+<versionCode>.aab` (coincidint amb
  `pubspec.yaml`).
- Si una build surt trencada, **esborra-la** d'aquesta carpeta perquè no es pugi
  per error; deixa-hi només la bona.

---

## 5. Publicar a Play Console (Internal testing)

1. **Play Console** → app *Entertain* → **Testing → Internal testing**.
2. **Create new release**.
3. **Upload** l'AAB des de `/mnt/c/Users/rafa/Claude/entertain/`.
4. Omplir les **release notes** (què porta aquesta versió).
5. **Save** → **Review release** → **Save and publish** (Start rollout to
   Internal testing).
6. Els testers (incl. el Pixel 8 Pro de validació) reben l'actualització; primer
   pas de validació abans de promoure a Closed/Production.

Tracks de Play (recordatori): Internal testing → Closed testing → Production.

---

## 6. Checklist ràpid

- [ ] Branca correcta, canvis validats.
- [ ] `~/.config/entertain/local.json` existeix i té les dues claus.
- [ ] `versionCode` pujat respecte a l'últim AAB pujat a Play.
- [ ] Build **amb** `--dart-define-from-file`.
- [ ] AAB copiat a `/mnt/c/Users/rafa/Claude/entertain/` amb el nom de versió.
- [ ] Pujat a Internal testing + release notes + Save and publish.
- [ ] (Després de validar) commit/PR del bump i la feina.
