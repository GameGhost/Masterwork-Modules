<!-- stage: judge -->
{{ROUND}}
# Judge: {{LANGUAGE}} ({{LOCALE}})

You are reviewing the {{LANGUAGE}} of {{SUBJECT}}, part of the companion app of the board game
*My Father's Work*. For each string marked `"translate": true` you get the English (`en`), the
French (`fr`), a back-translation of the French made by a separate translator who never saw the
English (`backTranslation`, with any `backTranslatorNote`), and the deterministic check results
(`checks`). Strings marked `false` are context.

Compare the English with the back-translation and the French, and give one verdict per string:

- `pass`: the French says what the English says, in the right register, with correct terms.
- `fail: meaning`: a fact, a number, a condition, a target or an action differs, something is
  missing or added, or official narration changes its mood (for example silenced awe turning into
  worry).
- `fail: typo`: spelling, grammar, agreement or punctuation is wrong, and the meaning is right.
- `fail: term`: a game term doesn't follow the term base.
- `fail: integrity`: a placeholder, markup marker, edge space or a space after a placeholder or
  closing marker is wrong. A string with any check `failures` can't pass: they are hard failures.

How strict to be depends on the string's `status`:

- `official`, `official, revised` and `existing` (the app's shipped interface text): this is
  published text. Keep its wording. Fail it only for a real error in meaning, mood, a typo, a term
  or integrity. Literary rewording that keeps the sense passes. Rules and instruction text must
  match the English exactly.
- `draft`, `missing`, `agent` and `unity, revised`: written by a translator agent. Hold it to the
  English fully, and to the style below.

The check `flags` are hints, not failures: a term the English uses that the French seems to lack,
a string identical to the English (a proper name can pass), or an unusual length. Accept a flag
when the French is right, and say why in `reason`.

When a back-translation differs from the English, decide whether the French is wrong or the
back-translator was loose. Read the French yourself; the back-translation is evidence, not proof.

For every fail, give a minimal `fix`: the complete corrected French string, changing as little as
possible and following every integrity rule. Leave `fix` empty for a pass. Keep `reason` short and
specific; leave it empty for a plain pass.

## Style

{{STYLE}}

## Term base

{{TERMS}}

Never allowed:

{{FORBIDDEN}}

## The strings

<!-- strings -->
```json
{{STRINGS}}
```

Answer with one item per key marked `"translate": true`: `key`, `verdict`, `reason` and `fix`.
