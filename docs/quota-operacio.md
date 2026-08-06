# Operació de quotes (quota_defaults)

> Nota operativa. Des de la migració `20260806000000_quota_defaults_and_status_rpc.sql`,
> els límits de quota són configuració de servidor: cap constant al client ni a
> les Edge Functions. Cadena de resolució (`effective_quota_limit`):
> entitlement per grup (`quota_entitlements`) > default global (`quota_defaults`)
> > NULL (fail closed: la funció retorna error de configuració, mai un número
> inventat).

## Valors canònics (free tier)

| quota_key | monthly_limit |
|---|---|
| dish_assistant | 3 |
| menu_wizard | 2 |
| stock_photos | 10 |

Són el seed de la migració. Qualsevol altre valor a `quota_defaults` és un
override operatiu temporal i ha de constar aquí sota.

## Canviar un límit global (sense deploy ni release)

```sql
update public.quota_defaults set monthly_limit = <N> where quota_key = '<clau>';
```

Efecte immediat per a tots els grups sense fila d'entitlement, presents i
futurs. Les files de `quota_entitlements` (premium/per grup) sempre manen per
sobre.

> Via d'execució: l'usuari pot fer aquests UPDATE directament a l'editor SQL de
> l'Studio (zero migracions). Des de Claude Code, l'únic canal SQL cap a la BD
> vinculada són les migracions: els overrides operatius van en migracions
> pròpies clarament etiquetades (vegeu `20260806000100_launch_bridge_quota_override.sql`).

## Override vigent — pont de llançament (aplicat 2026-08-06)

Mentre hi ha pocs usuaris, límits alts perquè els primers usuaris puguin provar
(aplicat via la migració `20260806000100_launch_bridge_quota_override.sql`, amb
ASSERTs que verifiquen els valors i la cadena de resolució):

```sql
update public.quota_defaults set monthly_limit = 20 where quota_key = 'dish_assistant';
update public.quota_defaults set monthly_limit = 10 where quota_key = 'menu_wizard';
update public.quota_defaults set monthly_limit = 50 where quota_key = 'stock_photos';
```

### Reversió (quan creixi la base d'usuaris)

```sql
update public.quota_defaults set monthly_limit = 3  where quota_key = 'dish_assistant';
update public.quota_defaults set monthly_limit = 2  where quota_key = 'menu_wizard';
update public.quota_defaults set monthly_limit = 10 where quota_key = 'stock_photos';
```

En revertir, esborrar la secció "Override vigent" d'aquest document (o
substituir-la pel nou estat).
