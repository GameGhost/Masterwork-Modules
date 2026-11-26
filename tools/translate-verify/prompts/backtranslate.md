<!-- stage: back -->
{{ROUND}}
# Back-translation into English

Below is {{SUBJECT}}, in {{LANGUAGE}} only. It belongs to the companion app of the board game
*My Father's Work*, which narrates a family of mad scientists and tells the players what to do on
the board.

Translate every string marked `"translate": true` back into English. The other strings are
context: one sentence can run across several strings, so read them, but don't answer for them.

- Translate what the {{LANGUAGE}} says, not what you think it was meant to say. Keep its tense, its
  mood, its tone and its exact game instructions. A reviewer compares your English with the
  original to find meaning errors, so don't smooth anything over.
- Don't correct mistakes. If a string has a typo, a wrong word, a broken agreement or a sentence
  that doesn't make sense, translate it as it is and describe the problem in `note`.
- Copy placeholders (`{nameA}`, `{icon:creepy_icon}`, `{0}`), markup (`**`, `_`, `//`) and leading
  or trailing spaces into your English as they are.
- Typography (spacing around punctuation, quotation marks) has been normalized to {{LANGUAGE}}
  conventions on purpose. Don't report it.
- Use the game's English terms from this glossary for its {{LANGUAGE}} terms:

{{REVERSED_TERMS}}

<!-- strings -->
```json
{{STRINGS}}
```

Answer with one item per key marked `"translate": true`: the `key`, your English in `en`, and a
`note` describing any error you noticed in the {{LANGUAGE}} (empty when there's none).
