<!-- stage: forward -->
# Forward translation: {{LANGUAGE}} ({{LOCALE}})

You are translating {{SUBJECT}} from English into {{LANGUAGE}}. It belongs to the companion app of
the board game *My Father's Work*, which narrates a family of mad scientists across three
generations and tells the players what to do on the board.

Below is the whole passage in reading order. Each string has a key, its English, its current French
(`fr`, `null` when there is none) and a `status`:

- `official`: official French from the published French edition of the app. Context only.
- `draft`: official French that couldn't be paired with this key one to one. The `fr` is the
  official text for the whole line it sat in, so it may also cover neighbouring keys, miss part of
  this key, or be one of several wordings of a shared key. Cut and adapt it so this key says exactly
  what its English says, keeping the official wording wherever it fits. Write what's missing in the
  same register. Fix plain errors in the official text (a typo, a wrong icon placeholder, a wrong
  gender agreement) and say so in your note.
- `missing`: no French. Write it. A `unityDraft` is the Unity app's French for it: revise that.

Write a string for every item marked `"translate": true`, and only for those. Items marked
`false` are context: read them so each string fits the sentence it sits in, since one sentence can
run across several keys, but never answer for them. A key used in other passages too
(`alsoUsedIn`) needs one string that fits every use.

## Integrity

Each string is shown on its own, one line, and spliced together with its neighbours at run time.

- Keep every placeholder exactly: `{nameA}`, `{icon:creepy_icon}`, `{0}`. Never translate, add or drop
  one. Reorder them only when the grammar needs it.
- Keep the markup counts: `**bold**`, `_italic_`, `//…//`, `___` blanks, and HTML tags in app strings.
  Put each marker around the equivalent words.
- Keep leading and trailing spaces exactly as the English has them. They join the string to its
  neighbours.
- Keep a space after a placeholder or a closing marker wherever the English has one.
- One line: no line breaks, no backslashes.

## Style

{{STYLE}}

## Term base

Use these renderings. A scenario's own list comes from its official French: use it for names of
cards, places and people.

{{TERMS}}

Never write:

{{FORBIDDEN}}

## The passage

<!-- strings -->
```json
{{STRINGS}}
```

Answer with one item per key marked `"translate": true`: the `key`, your French in `fr`, and a `note`
for anything a reviewer should know (an official error you fixed, a term you weren't sure of, text
you cut or added). Leave `note` empty when there's nothing to say.
