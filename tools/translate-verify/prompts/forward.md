<!-- stage: forward -->
# Forward translation: {{LANGUAGE}} ({{LOCALE}})

You are translating {{SUBJECT}} from English into {{LANGUAGE}}. It belongs to the companion app of
the board game *My Father's Work*, which narrates a family of mad scientists across three
generations and tells the players what to do on the board.

Below is the whole passage in reading order. Each string has a key, its English, its current
{{LANGUAGE}} (`translation`, `null` when there is none) and a `status`:

- `official`: the publisher's own translation. Context only.
- `existing`: a translation already in use, such as a community translation. Context only.
- `draft`: a translation that still needs revising, often official text that couldn't be paired
  with this key one to one. Then it is the text for the whole line it sat in, so it may also cover
  neighbouring keys, miss part of this key, or be one of several wordings of a shared key. Cut and
  adapt it so this key says exactly what its English says, keeping its wording wherever it fits.
  Write what's missing in the same register. Fix plain errors in it (a typo, a wrong icon
  placeholder, a wrong agreement) and say so in your note.
- `missing`: no translation. Write it. A `priorDraft` is an earlier translation of it from another
  source{{DRAFT_SOURCE}}: revise that.
- Any other status (`official, revised`, `agent`, …): text already verified. Context only.

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

Use these renderings. A scenario's own list comes from its existing translation: use it for names
of cards, places and people.

{{TERMS}}

Never write:

{{FORBIDDEN}}

## The passage

<!-- strings -->
```json
{{STRINGS}}
```

Answer with one item per key marked `"translate": true`: the `key`, your {{LANGUAGE}} in
`translation`, and a `note` for anything a reviewer should know (an error you fixed, a term you
weren't sure of, text you cut or added). Leave `note` empty when there's nothing to say.
