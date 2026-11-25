<!-- stage: judge -->
{{ROUND}}
# Judge: {{LANGUAGE}} ({{LOCALE}})

You are reviewing the {{LANGUAGE}} of {{SUBJECT}}, part of the companion app of the board game
*My Father's Work*. For each string marked `"translate": true` you get the English (`en`), the
{{LANGUAGE}} (`translation`), a back-translation of it made by a separate translator who never saw
the English (`backTranslation`, with any `backTranslatorNote`), and the deterministic check results
(`checks`). Strings marked `false` are context.

Compare the English with the back-translation and the {{LANGUAGE}}, and give one verdict per string:

- `pass`: the {{LANGUAGE}} says what the English says, in the right register, with correct terms.
- `fail: meaning`: a fact, a number, a condition, a target or an action differs, something is
  missing or added, or narration that was already translated by a person changes its mood (for
  example silenced awe turning into worry).
- `fail: typo`: spelling, grammar, agreement or punctuation is wrong, and the meaning is right.
- `fail: term`: a game term doesn't follow the term base.
- `fail: integrity`: a placeholder, markup marker, edge space or a space after a placeholder or
  closing marker is wrong. A string with any check `failures` can't pass: they are hard failures.

How strict to be depends on the string's `status`:

- `official` and `official, revised` (the publisher's translation) and `existing` (a translation
  already in use, such as a community translation or the app's shipped interface text): this text
  was written by a person. Keep its wording. Fail it only for a real error in meaning, mood, a
  typo, a term or integrity. Literary rewording that keeps the sense passes. Rules and instruction
  text must match the English exactly.
- Anything else (`draft`, `missing`, `agent`, or a revised prior draft such as `unity, revised`):
  written or reworked by a translator agent. Hold it to the English fully, and to the style below.

The check `flags` are hints, not failures: a term the English uses that the translation seems to
lack, a string identical to the English (a proper name can pass), or an unusual length. Accept a
flag when the translation is right, and say why in `reason`.

When a back-translation differs from the English, decide whether the translation is wrong or the
back-translator was loose. Read the {{LANGUAGE}} yourself; the back-translation is evidence, not
proof.

For every fail, give a minimal `fix`: the complete corrected {{LANGUAGE}} string, changing as little
as possible and following every integrity rule. Leave `fix` empty for a pass. Keep `reason` short
and specific; leave it empty for a plain pass.

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
