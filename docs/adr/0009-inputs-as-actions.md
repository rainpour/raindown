# 9. Inputs as actions

- Status: Accepted, for a directive's props, the rest to do as inputs need it
- Date: 2026-11-17

## Context

Raindown's an app framework on plain files: a project's files are its state, its nodes work out what a note shows from them, and writing the note back, or rendering it, is how what's shown follows a change. What it hadn't got was a way for an input, like a button, to say what it changes, so each one was wired up on its own, in the host it's in:

- **A `table:` table** is edited as Markdown, and the node writes it to its CSV, telling which side changed by the hash of its rows.
- **An endpoint** fetches again when its code block's emptied.
- **A rasterize button** in the [app](https://github.com/rainpour/raindown-app), which a node paints with `button(x:, y:, width:, height:, set:)`, changed props on its directive with a regular expression in the app's JavaScript, `directive_props.js`, apart from how Raindown reads directives, in `NodeBlocks`. So it could read one differently, and in a grid's row, where two cells' directives have the same prop, it changed the first.
- **The Obsidian plugin's table keys**, like Enter and Tab, edit the Markdown in CodeMirror.
- **The terminal UI's Run** runs an endpoint.

A button's edit had shown at once, as the app made it, and an input must still, as clicking and waiting for a trip to Raindown feels slow.

An input that only changes the note it's in can send the note as it changes it, which Raindown writes back as if it were typed. But an input that changes what the host hasn't got, or can't work out, can't: a row of a CSV file, another note's front matter, a note made from a template, or what a node's Ruby decides, like moving the done tasks to another note.

## Decision

**An input says what it does, as an `Action`, which Raindown takes, with the last word, and a host takes at once too, so it shows straight away.**

- **`Raindown::Action`**, in `lib/raindown/action.rb`, sets props on the directive on a line, or in a grid's cell, by the column it starts at, reading it with `NodeBlocks`, and leaves a note as it was for a prop the directive hasn't got, or a line that isn't one.
- **Raindown takes it as it writes a note back.** `Editing.rewrite_markdown(..., actions:)` takes each action, then writes the note back as it always has, so a node writes with the props it's given, and a project's worker, `raindown server` and the app pass them on.
- **A host takes it at once too, with `raindownAfterAction`**, in `lib/raindown/js/action.js`, a plain script, like `services.js`, which every host can run: the app gets it from Raindown as it starts, and the Obsidian plugin will put it in `main.js`, with `services.js`, when it has inputs. It reads directives with `NodeBlocks`' patterns, and `spec/raindown/action_spec.rb` runs it in QuickJS, checking it gives the same Markdown as `Raindown::Action` for each case, and knows Raindown's own nodes' names, so the two can't drift apart without a failing spec. What Raindown writes back has the last word, so where they'd differ, it's put right as the note's written back.
- **An input's action is one step to undo**, unlike Raindown's write-backs, as it's the user's.
- **A spinner turns beside the line** while Raindown's yet to take an action on it, in the app's gutter, in the cell before its number.
- **A directive decides which inputs it has.** A button for a prop its directive hasn't got isn't one: `Rasters` leaves it out of a Ruby node's painting, and the app out of a JavaScript node's, by its props, rather than the app reading the directive's line.

### What it's for, next

The actions that need Raindown, rather than a host, are those that reach past the note, which each input added will need:

| Input                                   | Its action                                                                         |
| --------------------------------------- | ---------------------------------------------------------------------------------- |
| A habit tracker's day, ticked           | A cell of `habits.csv`, checked against the row's hash, like `table:`'s           |
| A card dragged across a kanban board, from a query like [ADR 8](0008-querying-notes-with-data-expressions.md)'s | `status:` in the front matter of the note it shows |
| A form, like "Add expense"              | A row added to `expenses.csv`, with what a node works out, like today's date       |
| A node's action, like "Archive done tasks" | What its Ruby returns: tasks moved from one note to another                     |
| "Approve"                               | `approved_by:` and `approved_at:` set when Raindown takes it, not when it was drawn |
| An endpoint's Run, anywhere             | Its response, fetched again, as the terminal UI's Run does                        |

So `Action` grows targets: a front matter key, a task's line, a data file's row, a new row or note, each with the value it expects to change, so an action taken after the file changed, like on a phone that was offline, is refused, rather than writing over the change. And a node's own action, a method returning actions, gives a button what only its Ruby knows, while what it does is still changes to files, which can be seen, undone and checked in git.

**An action's the same from anywhere.** As it's data, the same action can come from a button in the app, an input in Obsidian's reading view, `raindown act note.md --line 3 --set zoom=9`, an agent's tool, or a spec, so a dashboard's buttons can be tested without an app, and anything a person can do on one, an agent can.

### Options considered

|                              | Actions, taken by Raindown and at once by the host (chosen) | The note sent as the host changes it | Actions taken by Raindown only |
| ---------------------------- | ---------------------------- | ------------------------------- | -------------------------- |
| Shows                        | At once, a spinner till it's taken | At once                     | After a trip to Raindown   |
| Reads directives             | As Raindown does, with a spec checking the host's copy | However each host does | As Raindown does   |
| Can change other files, or run a node's Ruby | Yes, as actions get targets | No, only the note it's in | Yes                      |
| Callable from the CLI, agents and specs | Yes                 | No                              | Yes                        |
| Code                         | An action in Ruby and JavaScript, and a spec keeping them together | A host's own, in each   | An action in Ruby          |

**Sending the note as the host changes it** is all a directive's props need, and Raindown writes back the note it's sent as if it were typed. But it leaves each host reading directives its own way, and can't reach past the note. **Actions taken by Raindown only** read directives one way, but a button's change would wait for a trip to Raindown to show.

## Consequences

- A button's change shows at once, as before, and Raindown takes its action again as it writes the note back, with the last word, while a spinner turns beside its line.
- The app no longer reads directives with its own regular expression, and a button in a grid's cell changes its own cell, rather than the first in the row with the prop.
- The action's in Ruby and JavaScript, kept together by a spec, which a change to how `NodeBlocks` reads directives has to keep passing, as does a new node of Raindown's own, whose name `action.js` needs.
- A host sends each action with the note it's in, which it's already taken, so Raindown taking it again changes nothing, unless they'd differ, or the host couldn't take it, like before its script's loaded.
- Each input that reaches past the note, like a CSV's row, needs a target for `Action`, and an ADR of its own if it changes how they work.

## Revisit when

- **An input needs to change what the host hasn't got**, like a CSV's row or another note, which is when `Action` gets its next target.
- **The Obsidian plugin has inputs**, which put `action.js` in its `main.js`, and a spinner in reading view.
- **An agent, or the CLI, needs to do what a person can on a dashboard**, which is when actions get a command, and a tool.
