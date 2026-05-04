-- Sprint 4 / S-Tier: Aktiviert pg_cron + pg_net, damit
-- send-notifications täglich automatisch laufen kann. Das eigentliche
-- Scheduling (cron.schedule(...)) wird einmalig manuell ausgeführt
-- nach dem Setzen von vault-Secrets — siehe
-- supabase/functions/send-notifications/SETUP.md.

CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;
