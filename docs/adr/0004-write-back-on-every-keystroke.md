# 4. Writing back on every keystroke in the Obsidian plugin

- Status: Accepted
- Date: 2026-11-07

## Context

The Obsidian plugin gives a note to `raindown server` as you type, and applies what comes back, so tables of contents, tables and lists stay up to date in the note. Until now it waited for typing to pause, for `TYPING_DELAY`, which was 250ms.

Trying `table:` totals and formulas in Obsidian felt slow, and lowering the delay changed nothing. A timing log in the plugin showed why: the delay wasn't what we were waiting for.

- **Raindown crashed on every request.** An app opened from the Dock starts programs with no locale, so Ruby read text as US-ASCII, and the `·` in a table's comment stopped the server. The plugin restarted it each time, which took about 600ms, and never got an answer.
- **A second writer hid the crash.** A `raindown` running on `~/dev` was writing back to the vault when Obsidian saved, about 2 seconds after typing stopped. Files outside a project fell back to the folder it was opened on.

With both fixed, a write-back takes a few milliseconds, so waiting for a pause no longer saves anything noticeable. Taking the wait away showed three problems the wait had been hiding:

- **A write-back can move the cursor.** It was applied as one replacement, from the first difference to the last. When a table lines up again, that runs from its comment to the row being typed in, with the cursor inside it.
- **A write-back has side effects, even when its answer's thrown away.** The server writes a table's edits to its CSV file. If another key was typed before the answer arrived, the plugin dropped the answer, along with the table's new hash, so the next request looked like both the table and the file had changed: a false `<!-- table conflict -->`.
- **Text can be valid partway through typing it.** Obsidian closes brackets, so `=sum(c)` is a whole formula on the way to `=sum(cost)`, and it was worked out before the next key.

## Decision

**`TYPING_DELAY` is 0: the plugin writes back on every keystroke.** It stays a constant in the plugin's `main.js`, so it's easy to change. It isn't a setting, as nobody has needed one yet.

**Only one write-back of a note runs at a time.** `writeBackInTurn` remembers keys typed during one, and runs once more when it's done, with the note as it is by then. So requests can't pile up, and a slow note writes back as often as it can, rather than once a key. On a big note, this behaves like a delay without needing one.

**An answer for a note that's changed since still updates its table comments.** `tableCommentChanges` copies the comments over and leaves everything else alone, so the note always says what its CSV files hold. It needs the queue above: without it, the next request is already on its way with the old hash.

**A write-back changes each changed line on its own, and puts the cursor back.** `changedLines` makes the changes, and `movedCursor` keeps the cursor after the same text on its line, however its spaces moved, and after a space just typed. When lines are added or removed, it's still one replacement, as a table lining up again never does that.

**Typing a formula in a table waits for `DELAY`, a second.** While the cursor's in a cell starting with `=`, there's no way to tell a finished formula from one on its way somewhere else. A formula naming a column that doesn't exist also shows as it's written, rather than as an error, so it can be typed through.

**Raindown reads Markdown as UTF-8 whatever the locale**, and **a vault has one writer**: a Raindown watching a folder above a vault leaves it alone, and the plugin's own server writes back to it.

### Measurements

One keystroke's write-back through `raindown server`, on notes of prose with a `toc:`:

| Note size | Typical | Worst |
| --------- | ------- | ----- |
| 5KB       | 13ms    | 20ms  |
| 50KB      | 75ms    | 85ms  |
| 200KB     | 285ms   | 320ms |
| 1MB       | 1.6s    | 1.7s  |

The size of the vault barely matters. A 5KB note in a vault of 100 files takes 14ms, and in one of 10,000 files, 26ms.

So the cost is about 1.5ms per KB of the note. This doesn't include Obsidian's side, like comparing lines and highlighting, or notes full of tables, or a project's own nodes.

### Options considered

|                       | 0ms and a queue (chosen)                  | 100ms                              | Scaled by note size                  |
| --------------------- | ----------------------------------------- | ---------------------------------- | ------------------------------------ |
| Feels                 | Immediate                                 | Close, with a small lag            | Immediate on most notes              |
| Requests while typing | One a key, or as fast as Raindown answers | One a pause, and a pause is common | One a key on small notes             |
| Big notes             | Raindown stays busy while you type        | The same, as pauses are short      | Less work                            |
| Race with the CSV     | Needs the queue and comment updates       | Needs them too, but shows up less  | Needs them too                       |
| New code              | None beyond what any delay needs          | None                               | A rule to pick the delay, and tuning |

**A delay doesn't remove any of the problems above, only makes them rarer.** The cursor, the false conflict and the formula can all happen at 250ms, on a slow answer or a pause in the wrong place. So they're fixed where they happen, and the delay's free to be whatever feels best.

## Consequences

- Typing never waits for Raindown, which runs in a process of its own. A slow write-back only delays when the update appears.
- Raindown runs for every keystroke, so a project's node that's slow, like one reading a lot of files, is felt while typing. Nodes that write outside the note run on every key too.
- On a note of a few hundred KB or more, Raindown stays busy for as long as you type, which costs CPU and battery.
- Each write-back that finishes writes a table's edits to its CSV file, so a half-typed cell reaches the file, and is replaced as typing goes on. A formula's overwritten this way as soon as its cell's changed.
- A row still being typed reads the same in the table and its file, as `WrittenTable` pads its rows as they're read. So typing `|` on a new line becomes a whole blank row straight away.
- A formula with a typo, like `=sum(cots)`, stays as text, with no error to point it out.
- Pausing for over a second in a formula still works it out, if the column it names so far exists.
- The **Write back** commands skip the queue, so running one partway through typing can still cause a false conflict.

## Revisit when

- **Notes this large are common, or typing feels heavy.** Scale the delay by the note's size, like 0 below 100KB and 250ms above it, or skip write-backs while the note's above a size.
- **A node makes typing slow.** Let a node say it's slow, so it only runs on save, or give it a delay of its own.
- **Pausing partway through a formula is a problem.** Wait for the cursor to leave the cell, like Enter in a spreadsheet, with a rule for when it never does.
- **Other editors write back as you type.** The VS Code extension talks to the same server, so it needs the same queue and comment updates, and they may belong in a shared protocol, like the server only writing to files once it's told the answer was used.
