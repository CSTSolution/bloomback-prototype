# Question bank (Chi, thread 0007)

`questions.json` holds BloomBack's daily health-knowledge questions. **Chi approves every question before it ships**: the app shows only questions with an `approved` date and skips the rest, so drafts can sit in the file safely.

| Field | Required | What |
|---|---|---|
| `id` | yes | Unique, stable, kebab-case, e.g. `sleep-adult-hours`. Never reuse an id for a different question (the phone remembers which ids it has shown). |
| `topic` | yes | `sleep`, `movement` or `numbers`. Sleep and movement questions follow the user's chosen areas; `numbers` (common health numbers) are mixed in at about 1 in 5. |
| `question` | yes | `{ "en": "...", "ar": "..." }`. `ar` is optional for now (the app shows English). |
| `choices` | yes | 2 to 4 items, each `{ "en": "...", "ar": "..." }`. |
| `answer` | yes | Index of the right choice, from 0. |
| `explanation` | yes | 1 or 2 sentences, `{ "en": "...", "ar": "..." }`, in the health organisation's own words and terms. |
| `askDoctor` | yes | `true` for any lab or body number: the answer screen adds "Want to understand your own numbers? Ask your doctor." |
| `sources` | yes | 1 or more `{ "title": "...", "url": "..." }`: the official source shown under "?". No source, no question. |
| `approved` | for shipping | `YYYY-MM-DD` Chi approved it. Leave it out (or `null`) for a draft. |
| `approvedNote` | no | Who or where, e.g. "Chi, thread 0007". |

Rules (Chi's principles): no scores, no right/wrong count, no streaks; general knowledge only, never the user's own numbers; source wording; range names exactly as the source says them, never "good" or "bad".

Check the file with `cd app && flutter test test/quiz_test.dart` (it fails on a missing field, a bad answer index, a duplicate id or an approved question without a source).
