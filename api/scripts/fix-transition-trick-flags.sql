-- One-off data cleanup: transition tricks (e.g. "Combo") are connectors with
-- no foot/no-touch of their own, but before this was enforced in the app,
-- ComboTrick rows referencing a transition Trick could end up with
-- StrongFoot = false and/or NoTouch = true. Normalizes those back to the
-- only valid state (StrongFoot = true, NoTouch = false). Safe to re-run —
-- it's a no-op once nothing matches.
--
-- Usage:
--   docker exec -i freestylecombo-db-1 psql -U postgres -d freestyle_combo -f - < api/scripts/fix-transition-trick-flags.sql

BEGIN;

UPDATE "ComboTricks" ct
SET "StrongFoot" = true,
    "NoTouch" = false
FROM "Tricks" t
WHERE ct."TrickId" = t."Id"
  AND t."IsTransition" = true
  AND (ct."StrongFoot" = false OR ct."NoTouch" = true);

COMMIT;
