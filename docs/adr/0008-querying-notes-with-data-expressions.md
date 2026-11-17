# 8. Querying notes with data expressions

- Status: Proposed, to do one day
- Date: 2026-11-17

## Context

`list:` lists a project's Markdown files by their [metadata](../../README.md#metadata): front matter, and folders written with an underscore, like `_basics`. It filters by a value, like `list: tags: 'intro'`, orders by one field, and writes a link to each file, or renders them with a template. So it only sees what a note says about itself in front matter, and a vault organised the way Obsidian's are, with plain folders, `#tags` in the text and links between notes, is mostly invisible to it. Nor can it compare, like a rating of 4 or more, sort by several fields, limit, group, or write a table.

Obsidian's own tools do this, but none writes its result into the note:

- **Dataview** picks its data with `FROM`, from tags, including those in the text, real folders and their folders, a file, and links, `[[note]]` for the notes linking to it and `outgoing([[note]])` for those it links to, combined with `and`, `or` and `!`, then filters it with `WHERE`, in a language of its own, `TABLE rating FROM #book WHERE rating >= 4 SORT rating DESC`. It also reads inline fields, like `rating:: 9`, each file's `file.name`, `file.folder`, `file.mtime`, `file.tags`, `file.inlinks` and `file.outlinks`, and tasks, each with its status, text and fields.
- **Datacore**, Dataview's successor, a work in progress for JavaScript and TypeScript users, picks what a query's about with types, `@page`, `@section`, `@block`, `@task` and others, in one expression, like `@task and $completed = false and childof(@section and $name = "Daily")`, and shows the results with React.
- **Bases**, Obsidian's own, has no source: every file, narrowed by filters in YAML, like `file.hasTag("book")` and `file.inFolder("Required Reading")`, with formulas, in tables, lists, cards, kanban boards and maps, kept in a `.base` file or a code block.

Each shows its results only in Obsidian. On GitHub, in another editor, in git or to an agent, a note has a code block, not what it found. Raindown writes what a directive makes into the note, as Markdown, so its results would be read everywhere, and change in git like anything else.

[LowData](https://github.com/low-rb/low_data)'s data expressions build the shape of the result, rather than a query for it: `Posts(published: true)[:title] + Users[:username] ^ Col[:created_at] * 10` is posts, filtered in round brackets, with their columns in square ones, each nesting its user, sorted with `^` and limited with `*`. A table in round brackets keeps the rows that have related rows in it, like `Users(Posts(published: true))`, and `~` those that haven't. That shape is what Raindown would write back: a list, a table, or lists nested in lists.

## Decision

**Query a project's notes, tags, links and tasks with data expressions, like LowData's, in `list:`, writing the result back as Markdown in the shape of the expression.** The props `list:` takes now stay, for what they do, and an expression is for what they can't:

```md
<!-- list: Notes(tags: 'book') { rating >= 4 }[:title, :author, :rating] ^ -Col[:rating] * 10 -->
| Title                     | Author         | Rating |
| ------------------------- | -------------- | ------ |
| [Dune](books/dune.md)     | Frank Herbert  | 5      |
| [Piranesi](books/pira.md) | Susanna Clarke | 4      |
<!-- :list -->
```

### Tables

A project's index, made from its files, as tables, each related to a note:

| Table      | A row is                       | Columns                                                                          |
| ---------- | ------------------------------ | -------------------------------------------------------------------------------- |
| `Notes`    | a Markdown file                | its front matter, `title`, `name`, `path`, `folder`, its real folder, `created`, `modified`, `tags` |
| `Tags`     | a tag on a note                | `name`, and the note's, in front matter or the text, `#a/b` also tagging `a`       |
| `Links`    | a link from one note to another | `from` and `to`, from wikilinks and Markdown links                              |
| `Tasks`    | a `- [ ]` or `- [x]` item      | `text`, `done`, `line`, the heading it's under, and its inline fields             |
| `Sections` | a heading and what's under it  | `name`, `level`, `line`                                                           |

### What an expression is

| Want                               | Expression                                              |
| ---------------------------------- | ------------------------------------------------------- |
| Notes in a folder, and its folders | `Notes(folder: 'recipes')[:title]`                      |
| Notes tagged egg                   | `Notes(tags: 'egg')[:title]`, or `Notes(Tags(name: 'egg'))[:title]` |
| Notes linking to Dashboard         | `Notes(Links(to: 'Dashboard'))[:title]`                 |
| Notes Dashboard links to           | `Notes(Links(from: 'Dashboard'))[:title]`               |
| Notes without tags                 | `Notes(~Tags)[:title]`                                  |
| Comparisons                        | `Notes(tags: 'book') { rating >= 4 }[:title]`           |
| Several of them                    | `Notes { (rating >= 4) \| featured }[:title]`           |
| Sorted, most first, and the first 10 | `Notes[:title] ^ -Col[:rating] * 10`                  |
| Open tasks, under their notes      | `Notes[:title] + Tasks(done: false)[:text]`             |

A list of values filters by any of them, `Notes(status: %w[reading paused])`, a range by those in it, `Notes(rating: 4..)`, and a list in the front matter, like `tags`, by having one, as `list:` does now. `#` starts a comment in Ruby, so a tag's a table, `Tags(name: 'egg')`, rather than `#egg`.

### What it writes back

The expression's shape is the Markdown's:

- **One column**, a list of links, as `list:` writes now: `Notes(tags: 'book')[:title]`.
- **Several**, a table, its first column linking to each note, lined up as Raindown lines up every table: `Notes[:title, :rating]`.
- **Nested**, each row's nested rows in a list under it, like each note's open tasks under its title: `Notes[:title] + Tasks(done: false)[:text]`.

In `<{ }>`, it only renders, and a template, `<{ list: page Notes(tags: 'book') }>`, repeats for each row, as it does now.

### Parsed, never run

Raindown parses a prop's value with Prism already, so it parses an expression with Prism too, and evaluates only the nodes an expression can have: tables, their filters, a block's comparisons, `&` and `|`, `~`, `^`, `-`, `Col`, `*` and `+`. Anything else, like a method call, is an error at the directive, so a vault from someone else can't run code through a note. A project's own nodes, in `.raindown`, are Ruby, and can use the same expressions, and anything else.

### Its engine

LowData makes SQL for a database, through Sequel, which can't run in the Obsidian plugin's WebAssembly, and a project's index isn't one. So Raindown evaluates expressions itself, over its index, in memory, with LowData's syntax and, where it can share it, its parser, but not its SQL. The index is made as a project's files are read, and in the Obsidian plugin, from what Obsidian's metadata cache already has: each note's front matter, tags, links and headings.

### Keeping results fresh

What a `list:` writes depends on other files, so it's stale once one of them changes. Raindown keeps which notes have one, and when a note's front matter, tags, links or tasks change, `raindown watch`, the desktop app and the Obsidian plugin write those notes back too.

### Options considered

|                       | Data expressions (proposed) | More props on `list:`, like `where:`, `order:`, `group:` and `as:` | A query language, like Dataview's | YAML filters, like Bases' |
| --------------------- | --------------------------- | ----------------- | --------------------------- | ------------------------- |
| What it can say       | Sources, comparisons, sorting, limits, nesting | Comparisons, sorting, limits, grouping, in strings of their own | All of it | Filters and formulas |
| The result's shape    | The expression's            | Props for it      | A keyword, `TABLE` or `LIST` | A view, in Obsidian       |
| For whom              | Ruby users, and anyone with a pattern to copy | Anyone | Dataview's users | Anyone, with Obsidian's interface |
| Runs code from a note | No, as it's parsed          | No                | No                          | No                        |
| Shared with           | LowData, and a project's Ruby nodes | Nothing   | Nothing                     | Nothing                   |

**More props on `list:`** would cover the most common queries, and keep to how directives are written, but each prop would grow a little language of its own, `where: "rating >= 4 and status != 'read'"`, `order: '-rating, title'`, and they'd never express nesting, like tasks under their notes.

**A query language like Dataview's** would be familiar to its users, but it's a second language beside Markdown and Ruby, which Raindown would design and keep alone.

## Consequences

- A vault organised by folders, tags and links, as Obsidian's are, can be queried as it is, with what's found written into the note, where it reads the same in Obsidian, on GitHub, in git and to an agent.
- `list:` takes either props, as now, or an expression, and what it writes for props doesn't change.
- Raindown keeps an index of a project's tags, links, tasks and headings, besides its front matter, which takes time to make as it starts, and memory, as the plugin's Ruby only collects garbage between requests.
- Its syntax is LowData's, so it follows LowData as that changes, or keeps to a subset. `&` and `|`, rather than `&&` and `||`, which Ruby can't overload, are easy to get wrong, and an expression's terse for someone who doesn't write Ruby, so the README needs a pattern for each common query.
- Writing back the notes a change affects, rather than only the one saved, can write many notes for one edit, like a tag added to a note many lists show.

## Revisit when

- **People ask for queries `list:`'s props can't do**, like comparisons, several sources, or tasks.
- **LowData's syntax settles**, so Raindown's expressions needn't follow its changes.
- **Obsidian's Bases, or Datacore, write their results into the note**, which would take away what's Raindown's own in this.
