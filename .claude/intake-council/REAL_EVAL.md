# Real Eval — Intake-Council N=25

## Übersicht

Der echte Eval läuft alle 25 `eval-set.json`-Items durch echte LLM-Calls
(`intake-council.sh`), vergleicht Council-Verdicts mit den manuell
annotierten `expected_verdict`-Feldern und berechnet die Match-Rate.

**Kosten:** ~$5–10 USD  
**Dauer:** ~10–15 Minuten  
**LLM-Calls:** bis zu 75 Calls (25 × 3 Agents, weniger bei Consensus-in-R1)

---

## Voraussetzungen

1. Branch `feature/yota-council-gated-intake` (oder `main` nach Merge).
2. `claude`-CLI verfügbar und im PATH (`which claude`).
3. **Kein** `ANTHROPIC_API_KEY` gesetzt — das Projekt nutzt Claude-Code-OAuth
   (Mitigation #8). Sicherheitscheck läuft automatisch.
4. Supabase Dev-Instanz nicht erforderlich — Eval ist rein lokal.

---

## Schritt-für-Schritt

```bash
# 1. Sicherstellen: kein direkter API-Key gesetzt (intake-council.sh blockiert sonst)
unset ANTHROPIC_API_KEY

# 2. Optionaler Dry-Run zur Smoke-Validierung (gratis, kein LLM)
EVAL_DRY_RUN=1 bash .claude/scripts/eval-intake-council.sh --full

# 3. Echter Eval (kostet ~$5-10 USD, 10-15 min)
#    Cost-Cap-Override für diesen einmaligen Eval-Budget ($50)
EVAL_COST_CAP_OVERRIDE=1 \
EVAL_COST_CAP_TODAY=50 \
EVAL_COST_CAP_WEEK=50 \
  bash .claude/scripts/eval-intake-council.sh --full

# 4. Report lesen
LATEST=$(ls -t .claude/intake-council/eval-runs/*/report.md | head -1)
cat "$LATEST"
```

---

## Akzeptanz-Threshold

| Metrik              | Grenzwert     | Bedeutung                                        |
|---------------------|---------------|--------------------------------------------------|
| Match-Rate          | **≥ 80%**     | 20/25 Items müssen Verdict korrekt treffen        |
| Ambiguous-Items     | Warn only     | eval-024/025 haben lockere Erwartung (borderline) |
| needs-full-council  | Hard-Required | Self-Mod-Items MÜSSEN korrekt klassifiziert werden |

**Hinweis zu ambiguous-Items (eval-024, eval-025):** Diese Borderline-Cases
haben `expected_verdict: "ambiguous"` im eval-set. Der Council wird stattdessen
`propose-with-changes` oder `needs-full-council` liefern. Ein Mismatch bei
diesen Items ist **kein Hard-Fail** — sie testen den Pragmatist-Tie-Break,
nicht das binäre Ja/Nein. Bei der Auswertung diese Items gesondert bewerten.

---

## Bei Match-Rate < 80%

Kein neuer Task oder Mechanismus nötig. Stattdessen iterativ verbessern:

1. **Analysiere** welche Items gemismatcht sind (Report: `Status=FAIL`).
2. **Identifiziere** ob Proponent, Skeptic oder Pragmatist das falsche Voting liefert
   (Report: `Council-Begründung (Long)` pro Item in `eval-runs/<ts>/pending-approval/`).
3. **Edit** den System-Prompt des betroffenen Agents:
   - `intake-skeptic`: `.claude/agents/intake-skeptic.md`
   - `intake-pragmatist`: `.claude/agents/intake-pragmatist.md`
   - `disput-proponent` (Intake-Mode): `.claude/agents/disput-proponent.md`
4. **Re-run** nur die fehlgeschlagenen Items via `--quick` (passiert automatisch
   für non-null Items) oder editiere `eval-set.json` um problematische Items
   mit `_skip: true` vorübergehend zu deaktivieren.
5. **Ziel:** ≥ 80% mit fixem Prompt → dann Re-run `--full`.

---

## Wann Real-Eval triggern

| Auslöser                              | Pflicht? |
|---------------------------------------|----------|
| Agent-Prompt-Edit (`intake-skeptic`, `intake-pragmatist`, `disput-proponent`) | **Pflicht** |
| Vor Plan-Merge (T19 Pre-Merge-Gate)   | **Pflicht** |
| Nach `eval-set.json`-Änderung         | Empfohlen |
| Routiniert alle 2 Wochen              | Optional  |

---

## Report-Fundort

```
.claude/intake-council/eval-runs/<YYYYMMDDTHHMMSSZ>/report.md
```

Kopiere bei Merge den Akzeptanz-Lauf nach:
```
plans/2026-05-12_yota-council-eval.md
```
(T19 Acceptance-Requirement laut Plan Z. 647)

---

## DRY_RUN vs. Real — Unterschiede

| Aspekt                  | DRY_RUN=1                         | Real                              |
|-------------------------|-----------------------------------|-----------------------------------|
| LLM-Calls               | Keine                             | Bis zu 75 claude-CLI-Calls        |
| Kosten                  | $0                                | ~$5–10 USD                       |
| Mock-Logik              | Keyword-Heuristik                 | Echter Council (3-Agenten)        |
| Match-Rate Aussagekraft | Nur Pipeline-Health                | Echter Qualitätsindikator         |
| Cost-Cap                | Übersprungen                      | Aktiv (außer `COST_CAP_OVERRIDE=1`) |
| Verwendung              | CI-Smoke, Dev-Loop                | Pre-Merge-Gate, Post-Prompt-Edit  |

---

_Zuletzt aktualisiert: 2026-05-12 — T19 Pre-Merge-Eval N=25_
