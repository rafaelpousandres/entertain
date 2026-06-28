-- Specification 030 §B — schedule the `sweep-staging` Edge Function.
--
-- The project's first scheduled job. A daily cron purges abandoned blobs from
-- the `photo-staging` bucket (create flows that were cancelled / killed before
-- save). pg_cron fires an HTTP POST (pg_net) at the function, authenticating
-- with the service-role key — exactly the shared secret the function checks.
--
-- SECRETS STAY OUT OF THE MIGRATION (CLAUDE.md non-negotiable): the project URL
-- and the service-role key are read at run time from Supabase Vault, not
-- hard-coded here. The OPERATOR must create these two Vault secrets once (SQL
-- editor or dashboard → Vault), or the scheduled POST will be a no-op:
--
--   select vault.create_secret('https://<project-ref>.supabase.co', 'project_url');
--   select vault.create_secret('<service-role-key>',                'service_role_key');
--
-- NOTE FOR THE OPERATOR: enabling pg_cron / pg_net may need privileges the
-- migration role lacks on the hosted project. If `supabase db push` rejects the
-- `create extension` lines, enable both from the dashboard (Database →
-- Extensions) and re-run; the schedule block is idempotent (cron.schedule
-- upserts by job name).

create extension if not exists pg_cron;
create extension if not exists pg_net;

-- Daily at 04:00 UTC. cron.schedule upserts by job name, so re-running this
-- migration just refreshes the schedule.
select cron.schedule(
  'sweep-photo-staging',
  '0 4 * * *',
  $$
  select net.http_post(
    url := (
      select decrypted_secret from vault.decrypted_secrets
      where name = 'project_url'
    ) || '/functions/v1/sweep-staging',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || (
        select decrypted_secret from vault.decrypted_secrets
        where name = 'service_role_key'
      )
    ),
    body := '{}'::jsonb
  );
  $$
);
