-- ─── Deal-Kommentare / Notiz-Threads ──────────────────────────────────────
--
-- Eine separate Tabelle, weil ein Deal viele Kommentare haben kann und
-- jeder Kommentar einen eigenen Author + Timestamp braucht. Mit dem
-- Team-Modus später (s. workspaces-Migration) wird das zur Discussion-Wall
-- pro Deal.

CREATE TABLE IF NOT EXISTS public.deal_comments (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  deal_id     BIGINT      NOT NULL REFERENCES public.deals(id) ON DELETE CASCADE,
  user_id     UUID        NOT NULL REFERENCES auth.users(id)  ON DELETE CASCADE,
  author      TEXT        NOT NULL,
  body        TEXT        NOT NULL CHECK (length(body) > 0 AND length(body) <= 4000),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ,
  deleted_at  TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS deal_comments_deal_idx
  ON public.deal_comments(deal_id, created_at DESC)
  WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS deal_comments_user_idx
  ON public.deal_comments(user_id);

ALTER TABLE public.deal_comments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "user_owns_deal_comments" ON public.deal_comments;
CREATE POLICY "user_owns_deal_comments" ON public.deal_comments
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
