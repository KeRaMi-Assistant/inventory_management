-- Support-Kontaktformular (Stakeholder-Direktive 2026-06-12):
-- Settings → Support sendet Titel + Anliegen + Kunden-Kontext an den
-- Betreiber. Diese Tabelle ist die QUELLE DER WAHRHEIT — Mail (Resend)
-- und ntfy-Push sind Best-Effort-Zustellkanäle der Edge Function
-- `support-request`; fällt ein Kanal aus, geht nichts verloren.

CREATE TABLE IF NOT EXISTS public.support_requests (
  id           BIGSERIAL PRIMARY KEY,
  workspace_id UUID REFERENCES public.workspaces(id) ON DELETE SET NULL,
  user_id      UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  -- E-Mail des Absenders zum Antworten (aus dem JWT, nicht User-Input).
  email        TEXT NOT NULL,
  plan         TEXT,
  subject      TEXT NOT NULL CHECK (char_length(subject) BETWEEN 3 AND 150),
  message      TEXT NOT NULL CHECK (char_length(message) BETWEEN 10 AND 5000),
  app_version  TEXT,
  status       TEXT NOT NULL DEFAULT 'open'
               CHECK (status IN ('open','answered','closed')),
  -- Zustell-Telemetrie der Best-Effort-Kanäle.
  mail_sent    BOOLEAN NOT NULL DEFAULT false,
  push_sent    BOOLEAN NOT NULL DEFAULT false,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS support_requests_user_idx
  ON public.support_requests (user_id, created_at DESC);

ALTER TABLE public.support_requests ENABLE ROW LEVEL SECURITY;
-- Bewusst KEINE Policies → default-deny für anon/authenticated.
-- Schreiben/Lesen ausschließlich über die Edge Function (Service-Role):
-- so bleiben Rate-Limit + Validierung serverseitig unumgehbar und kein
-- Client kann fremde Support-Anfragen lesen.

COMMENT ON TABLE public.support_requests IS
  '2026-06-12: Support-Anfragen aus Settings → Support. Default-deny-RLS; '
  'nur die Edge Function support-request (Service-Role) schreibt. Mail/'
  'Push sind Best-Effort (mail_sent/push_sent), die Row ist die Wahrheit.';
