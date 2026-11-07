<a href="https://rubygems.org/gems/raindown" title="Install gem"><img src="https://badge.fury.io/rb/raindown.svg" alt="Gem version" height="18"></a> <a href="https://github.com/rainpour/raindown" title="GitHub"><img src="https://img.shields.io/badge/github-%23121011.svg?style=for-the-badge&logo=github&logoColor=white" alt="GitHub repo" height="18"></a> <a href="https://codeberg.org/Iow/raindown" title="Codeberg"><img src="https://img.shields.io/badge/Codeberg-2185D0?style=for-the-badge&logo=Codeberg&logoColor=white" alt="Codeberg repo" height="18"></a>

# Raindown

Raindown is a Markdown superset for AI, APIs, Docs and humans.

<!-- CodeDebt: -->
```
    █▀█   ▀▀█
▀▀▀ █ █    ▀█
    ▀▀▀ ▀ ▀▀▀
0 fixes
```
<!-- :CodeDebt -->

<!-- CodeHealth: -->
```
█▀█   █ █ █▀█
█ █   ▀▀█ █▀█
▀▀▀ ▀   ▀ ▀▀▀
10 felt
```
<!-- :CodeHealth -->

<!-- Commits: limit=5 -->
```
Total    -17 ████│██████████████████████████  +112
──────────────────────────────────────────────────
7d30bff   -4    █│████████████▌                +54
2ccc904   -7   ▐█│█████████▌                   +41
d025578   -3    █│███                          +13
f049700   -1    ▕│▌                             +2
02a0e4f   -2    ▐│▌                             +2
```
<!-- :Commits -->

## CLI

The gem ships a `raindown` executable that opens a project in the terminal, and watches its Markdown files and writes back to them as they're saved, like their tables of contents, tables and endpoint responses. `raindown watch` does the watching without the terminal UI.

```sh
# Make a project, cloning its .raindown folder of config and data from raindown-init:
raindown init

# Browse a project's files and their outlines in the terminal, watching them as they're saved:
raindown
raindown README.md

# Watch every project with a .raindown folder in the current directory, or in another one, without the terminal UI:
raindown watch
raindown watch ~/dev

# Watch one file:
raindown watch README.md

# Render to HTML once, to stdout or to a file:
raindown README.md --html
raindown README.md --html site/index.html

# Render Markdown from stdin without touching the file (for editor previews):
cat draft.rd | raindown draft.rd --stdin
```

With `--stdin`, FILE only decides whether bare directives are allowed (by its extension), so it doesn't need to exist yet, and the TOC and tables aren't written back to it.

`raindown watch` on a directory watches each project in it, a folder with a `.raindown` folder, and the Markdown files below it, skipping hidden folders, ones like `node_modules` and `build`, and the folders your `.gitignore` files name. An Obsidian vault, a folder with an `.obsidian` folder, is left alone when it's below the folder Raindown's watching, even with a `.raindown` folder of its own, so a `raindown` on `~/dev` and the [Obsidian plugin](https://github.com/rainpour/raindown-obsidian)'s own server don't both write back to its notes. Pointed at the vault itself, Raindown watches it as usual. The terminal UI only writes back to files in a folder's projects, or to any file saved in a folder with no projects. Each project's nodes load in a process of their own, so two projects can have nodes of the same name, and saving one of a project's nodes reloads them. Files are written back as they're saved, not all at once when watching starts.

`raindown` shows a project's Markdown files beside an outline of the open file's headings and directives, after Raindown's rain cloud while it loads. On a folder of projects, like `raindown ~/dev`, it shows only the projects' files, leaving out the Markdown outside them, and in a folder without a project the Dashboard says so, until `raindown init` makes one. It opens on the Dashboard (below), or on the file you name, like `raindown README.md`. Arrow keys or `j`/`k` move, Tab switches pane, and Enter opens a file or folder, or folds a heading. On a directive, Enter shows the lines it wrote back, `x` (or its `[Run]` button) runs an endpoint, and `e` opens your `$EDITOR` at the selected line, then writes back to the file when you close it. Like `raindown watch`, it watches every file in the folder, and writes back to each Markdown file as it's saved, so there's no need for `raindown watch` running in another terminal too. A click does what Enter does where it's clicked, or presses the button clicked, like `[Run]`, unless that would leave the TUI for your editor, so a stray click only moves the cursor. Scrolling does nothing.

**Dashboard**, at the top of the files (or `d`), shows every chart and stat in the project beside them, each in a card under its file and heading. The projects inside it, marked 🌧 in the files, are shown too, each with its own nodes, and their charts are under their paths. Click the path in the header, or press `p`, to narrow the files, the Dashboard, Code feelings and Blueprints to one project.

Below the files, after a blank line, is every endpoint in the project, by its request, like `GET httpbin.org/uuid`, with its method in colour: GET green, POST blue, DELETE red, PUT yellow and PATCH magenta. Enter or a click opens one beside the files, with its URL in a bar and a **Run** button, and its response below. `x`, or clicking **Run**, runs it, and Enter opens its directive in the outline. The charts are drawn from their data every few seconds, so editing a CSV file updates its chart without a save. Enter (or clicking a card's title) opens the chart's file in the outline, on its directive.

**Teleport** with `/`: type part of a file, heading, directive or endpoint, and Raindown finds it in every file, matching the letters in order, so `stp` finds `## Setup`. Up and down choose between the matches, Enter or a click goes there, and Esc closes it.

Code is highlighted with [Rouge](https://rouge.jneen.net), which knows over 200 languages: a directive's body when it's expanded in the outline, with its code blocks in their own languages, an endpoint's response, in the language of its code block, and the code in Code feelings, by its file's name.

**Code feelings**, under the Dashboard in the files (or `f`), shows the project's functions and methods as clusters of digits in a grid, like the refiners' screens in Severance. Each week it shows a batch of files, as many as fill the screen, the first in a random order for the week, under its title, Weekly Batch, with how much of it is refined at the top right of the grid. Felt methods go blank, and once they're all felt, that's the week's work done, and it rains over the whole screen, then a waffle pops out. A screen too small for a grid of 15 columns by 5 rows, as one under 24 lines tall is, goes red until it's bigger. It finds them in any language with [Universal Ctags](https://ctags.io) when it's installed, or else by how the code's indented. Long methods, and ones whose files keep changing, drift. Move between them with the arrow keys to see each one's code, its first 6 lines, or as much as fits with Enter or by clicking how many more lines there are. Sort how it makes you feel with `1` to `5`, from best to worst: frolic, numb, woe, dread or malice. Woe, dread and malice ask why, which you type, then Enter, or Esc to leave it out. Either way, the cursor stays on the method, ready to fix. Each feeling goes into its project's `.raindown/data/feelings.csv`, even in a folder of projects, with the commit it was felt at and a checksum of the method's code. Feeling a method again replaces how it felt. Once its code changes, or it's gone, its feeling moves to `.raindown/data/memories.csv`, so `feelings.csv` only says how the code feels now, and the method comes back into the grid to be felt again. The code health at the top of this README is their average from 0 to 1, with each feeling's score below, labelled with how many feelings it's the average of. The code debt adds up how far each is from numb, from 1 for frolic to -1 for malice, so it's in debt below zero, labelled with how many fixes there have been, feelings that scored higher when their method was felt again after its code changed. Both are stats in `.raindown`. `e` opens the method in your editor, and `x` asks [Claude Code](https://claude.com/claude-code) to fix it, with how it felt, when the `claude` command is installed. Either way, the code is read again after, to be felt again.

| Key     | 1      | 2    | 3   | 4     | 5      |
| ------- | ------ | ---- | --- | ----- | ------ |
| Feeling | frolic | numb | woe | dread | malice |
| Score   | 1      | 0.5  | ⅓   | ⅙     | 0      |

**Blueprints**, under Code feelings in the files once a project has some (or `b`), shows the mockups, diagrams, charts and tables drawn in [Claude Code](https://claude.com/claude-code)'s replies, newest first, then those drawn in the comments above the code's classes and methods, indented further than their prose, which describes them, one at a time. Each is traced to its code: ← and → move between the boxes drawn in one, in reading order, and ↑ and ↓ to the nearest box above or below, or click one, each showing the code it names in a box below, Code feelings' code box, its first 6 lines, or as much as fits with Enter or by clicking how many more lines there are, and Space, or clicking the box again, the next code it names, in the order it names it, which `e` opens, or the blueprint itself when the box names none. A blueprint bigger than the pane is on a canvas that follows the selected box, with `◀ ▶ ▲ ▼` at the edges where there's more, and scrolls with Shift and the arrows, or by dragging it with the mouse. The title above them, in the border, is the keywords they're filtered by: `f`, while the page is focused, or a click opens a filter like Teleport's, where they're typed, each a word in the blueprint or its kind, listing those that match, which ↑ and ↓ move between, to show another, Enter or a click keeps it, and Esc clears it. A blueprint is a code block marked with its kind, like `mockup`, or one with no language that's drawn with box-drawing lines or blocks, whose kind is worked out from what it's drawn with: a diagram when arrows join its parts, a chart when it's mostly blocks, a table when its lines cross, and otherwise a mockup. One line, or a first line opening a box that never closes, like a piece of a box quoted, isn't a blueprint. A box names code by a method, like `Watcher.listen`, a class, like `Workers`, whose first method it shows, or a method's name that only one method has. `raindown blueprints` saves those in Claude Code's last reply to the project's `.raindown/data/blueprints.md`, each under the time it was saved and its kind, with the paragraph above it in the reply, unless that's a list, a heading or another block, as its description, which the page shows above it, and the filter matches, as a Stop hook in Claude Code's settings:

```json
{ "hooks": { "Stop": [{ "hooks": [{ "type": "command", "command": "raindown blueprints", "async": true }] }] } }
```

The page shows a new blueprint as soon as it's saved, as the terminal UI watches the project's files.

### Directives

How a directive is written says what it does: bare and comment directives write their output into the file, and `<{ }>` directives only render into the HTML:

| Written as                                | Writes into the file           | Shows in the HTML         | Typical use                                                 |
| ----------------------------------------- | ------------------------------ | ------------------------- | ----------------------------------------------------------- |
| Bare `toc:`                               | Yes, up to the next blank line | In bold                   | `.rd` files, where you want to see where content comes from |
| `<!-- toc: -->` … `<!-- :toc -->`         | Yes, up to its end tag         | Hidden, also on GitHub    | Plain `.md` that should read cleanly anywhere               |
| `<{ toc: }>` … `<{ :toc }>`, `<{ Card }>` | Never                          | Hidden                    | Templates, layouts and render-only components               |
| `{title}` or `<{ title }>`                | Never                          | The value, escaped or raw | [Variables](#variables)                                     |
| `{:app_name}`                             | Never                          | The translation           | Translations                                                |

A colon after the name opens a block, like `toc:`, `<!-- toc: -->` or `<{ Card: }>`, and a colon before the name closes the block, which could be an end tag, like `<!-- :toc -->` or `<{ :Card }>`, or a self-closing tag, like a bare `:toc` or `<{ :toc }>`. A capitalized node can be self-closing without a colon, like `<{ Card }>`, while `<{ title }>` without one is a variable.

1. Bare directives work in [Raindown files](#raindown-files) (`.rd`) and in Markdown files (`.md`) with `raindown: true` front matter or `--bare` via the CLI.
2. All directive types can output HTML or Markdown that is rendered to HTML, it's up to you to enable it per component. See [Nodes](#nodes).

#### Template directives

Shape how the Markdown around them renders, like Liquid or Jinja: [variables](#variables) like `{title}`, loops with `for:` and conditions with `if:`. A [`list:`](#lists) block's template repeats like a loop, for each file it lists. You write their output as a template, and they decide whether it appears and how many times, filling in values like `{title}`. They're invisible in the HTML, since the input is a template, and showing them would break the tables and lists they often sit in.

#### Content directives

Bring content into the page: a [table of contents](#table-of-contents) with `toc:` and `:toc`, [lists](#lists) with `list:`, [charts](#charts) with `chart:`, [tables](#tables) with `table:`, [endpoints](#endpoints) with `endpoint:` and your own [nodes](#nodes). Raindown or your node writes their output, and you only give them input, like `folder: 'notes'` or an endpoint's curl snippet. Most also write their content into the Markdown below them, so it's there for people and agents reading the file. They sit on their own lines between content blocks. Written bare, they write back and show in bold in the HTML, so you can see where a page's content comes from. In HTML comments, like `<!-- toc: -->` and `<!-- :toc -->`, they write back and stay hidden, in the HTML and on GitHub. In `<{ }>`, like `<{ :toc }>`, they're write-in: they only render into the HTML, taking what's between their tags as input, and write nothing into the file.

### Raindown files

Raindown is a superset of Markdown. Give a file the `.rd` or `.raindown` extension and a content directive on its own line no longer needs delimiters:

```
# Notes

:toc
```

Bare directives write back, and have no end tags, so a bare block, like `toc:`, holds the Markdown straight below it, up to the next blank line. When its output needs blank lines, put it in comments with an end tag instead, which works in `.md` and `.rd`. Template directives, like `if:` and `for:`, are never bare, and always sit in `<{ }>`:

```
<{ if: draft }>
This is a draft.

It has two paragraphs.
<{ :if }>
```

Bare directives, like ones in comments, read like prose, so an unquoted word is text, like `list: folder: notes`, and only a word in braces is a variable, like `chart: {stats}`. Directives in prose or code are left as text.

Markdown files can opt in too, with `raindown: true` in their front matter:

```md
---
raindown: true
---

# Notes

:toc
```

Or with the `--bare` flag:

```sh
raindown README.md --bare
raindown watch README.md --bare
```

### Table of contents

`<{ :toc }>` renders a table of contents of the file's headings in the HTML. A single `#` heading at the start of the file is its title, so it's left out when there are headings below it.

A `<!-- toc: -->` block does that too, and also writes the table of contents into the Markdown below it as a list of links, updated whenever the file is rendered. That way people and agents reading the file see it as well, and on GitHub only the list shows:

```md
<!-- toc: -->
- [Setup](#setup)
  - [Install](#install)
<!-- :toc -->
```

The block needs `<!-- :toc -->` after it. In a [Raindown file](#raindown-files) it can be a bare `toc:` with the list straight below it, and `:toc` on its own is always the HTML table of contents.

`toc:` and `:toc` are a [node](#nodes), so a project can change them with its own `TOC` node, like `class TOC < Raindown::TOC`.

### Lists

`list:` lists the files in a folder, or with any other [metadata](#metadata), from your project's Markdown files. Bare or in comments it writes a link to each, by its title, into the Markdown, and renders them as a list in the HTML:

```md
<!-- list: folder: 'notes' -->
- [Getting started](docs/_notes/_1-getting-started.md)
- [Setup](docs/_notes/_2-setup.md)
<!-- :list -->
```

`<{ :list folder: 'notes' }>` renders the same links, writing nothing into the file. To render the files with your own template instead, name each file before the props, like `page`, in a `<{ list: }>` block. Its template repeats for each file, and only renders in the HTML:

```md
<{ list: page folder: 'notes' }>
## {page.title}
<{ :list }>
```

Files are listed by their `order`, or by any other metadata with `order:`, like `<{ list: page folder: 'notes' order: :created_at }>`, with files without it last.

`list:` is a [node](#nodes) too, so a project can list files its own way with a `List` node that overrides `rewrite` or adds `render`, like `class List < Raindown::List`, where `files(metadata:)` gives each file's front matter, `path` and `content`, for its links and its template.

### Wikilinks

Like in [Obsidian](https://obsidian.md), `[[Reading list]]` links to the file named `Reading list.md`, wherever it is in the project, whatever its case. `[[Reading list#To read]]` links to a heading, `[[Reading list|books]]` changes the text, and `[[notes/Reading list]]` picks one of two files with the same name. They render as links, by the file's path like `list:`, while the file keeps them as you wrote them, so Obsidian still reads it. Ones that name no file, embeds like `![[photo.png]]`, and ones in code are left as they are.

### Metadata

`list:` lists the Markdown files in your project by their metadata. The project is the folder with your [`.raindown`](#nodes) folder, or the top of your Obsidian vault, whichever's nearest, or else the folder of the file being rendered.

A file's front matter is its metadata, and a list like `tags: [ruby, intro]` tags it with each item:

```md
---
title: Getting started
tags: [ruby, intro]
---
```

Underscored folders in a file's path are metadata too. `docs/_basics/_1-getting-started.md` has:

```yaml
folder: basics
order: 1
path: docs/_basics/_1-getting-started.md
```

The `path` is relative to the project, so the links `list:` writes work in the Markdown, like on GitHub.

Files are listed by `order`, and separate several folder tags with `&`, like `docs/_1&_basics/getting-started.md`. Filter by any of them, like a folder or a tag:

```md
list: folder: 'basics'

list: tags: 'intro'
```

### Variables

Front matter keys are variables, which render with `{key}`, or `<{ key }>` to leave HTML unescaped:

```md
---
title: Release notes
author:
  name: Mark
tags: [ruby, markdown]
links:
  docs: https://raindown.dev
  code: https://github.com/rainpour/raindown
draft: false
---

{title}

{author.name}

<{ for: tag in: tags }>
- {tag}
<{ :for }>

<{ for: name, url in: links }>
- [{name}]({url})
<{ :for }>

<{ if: draft }>
This is a draft.
<{ :if }>
```

Variables, loops and conditions render before the Markdown does, like Liquid in Jekyll. A loop over a hash, like `links`, gets each key and value. So a loop's lines make one list or table, and a value can contain Markdown like `*emphasis*`. Unknown variables render nothing, and variables in code are left as text. Nested paths read keys and list items, like `{author.name}` and `{tags.0}`, a list's `first`, `last` and `size`, and a string's `upcase` and `downcase`, like `{title.upcase}`, but don't call other methods. `<{ key }>` doesn't escape HTML, so only use it for values you trust.

### Charts

A `chart:` block draws its data as a chart in block characters, and writes it into the Markdown below it as a code block, redrawn whenever the file is rendered:

````md
<!-- chart: 'data/downloads.csv' -->
```
Jan  ██████████████████████▌                  1,240
Feb  ███████████████████████████████████▉     1,980
Mar  ████████████████████████████████████████ 2,210
Apr  ███████████████▊                           870
```
<!-- :chart -->
````

Its data can be a CSV, TSV, JSON or YAML file relative to the project, numbers like `chart: '3 5 -2 8'`, or a [variable](#variables) in braces like `chart: {stats}`. A variable can hold either of those, or data of its own like a list of numbers or a hash of labels and values. A table's labels come from its first column and its values from the first column of numbers after it, or name them with `label:` and `value:`, like `value: 'sales'`.

`format:` draws it as `'bars'`, `'columns'`, a `'line'` or a `'sparkline'` (`▂▄▁▇▅█▃`). Without it, labeled data draws as bars and numbers alone as a sparkline. Negative values go below the line, or left of it for bars:

```
chart: 'data/profit.csv' width: 30
```
```
Jan              │██████████▉          1,200
Feb         ▕████│                      -450
Mar              │███████▎               800
Apr  ████████████│                    -1,300
May              │██████████████████▏  2,000
```

A line is drawn in braille, where each character has dots 2 across and 4 down, and shows the labels that fit below it:

```
chart: 'data/profit.csv' format: 'line' height: 6
```
```
 2,000 ┤                                       ⡠⠊
       │ ⢄⡀                                  ⢀⠔⠁
       │  ⠈⠑⠢⢄           ⢀⡠⠔⠊⠑⠤⡀           ⢀⠔⠁
     0 ┼──────⠉⠒⠤⣀───⣀⠤⠒⠉⠁─────⠈⠢⢄────────⡠⠊─────
       │          ⠉⠒⠉             ⠑⠢⡀   ⡠⠊
-1,300 ┤                            ⠈⠒⢄⠔⠁
         Jan      Feb       Mar      Apr      May
```

`minus:` names a column to chart against the values, like lines deleted against lines added. It goes left of the line for bars, below it for columns and sparklines, and as a second line below zero for a line:

```
chart: 'data/commits.csv' minus: 'deleted' width: 30
```
```
a8bb4fa  -44 ██│█████████▉                    +250
d6114e0  -11  ▐│▍                              +11
b12a47e   -4  ▕│▋                              +15
35cfe8c  -11  ▐│██▌                            +62
1f8ff0e   -5  ▕│████████████████████████████▎ +717
```

Bars and lines are 40 characters wide, and columns and lines 8 lines high, which `width:` and `height:` change.

`tail:` keeps only the last rows, like `tail: 12` for the latest twelve months of a CSV file that grows. In `raindown`'s terminal UI, the Dashboard draws charts again every few seconds, so a chart with `tail:` follows a file that a script appends to, like a live monitor.

`chart:` is a [node](#nodes), so a project can draw charts its own way with a `Chart` node, like `class Chart < Raindown::Chart`. Raindown only watches the file being rendered, so after changing a chart's data, save the file to redraw it.

A stat is one big number, like the code debt at the top of this README. Make one with a node that's a `Raindown::Stat`, which gives its `value` and `label`, and optionally how its `number` is written, like with a sign. Raindown draws the number in block digits above the label:

```ruby
# .raindown/issues.rb
class Issues < Raindown::Stat
  def value(metadata:) = Issue.open.count
  def label = 'open issues'
end
```

Then `<!-- Issues: -->` and `<!-- :Issues -->` in a file write it there. An opening tag needs its colon, even without props.

### Tables

A `table:` block writes a CSV or TSV file, relative to the project, as a Markdown table, after a comment of how many rows it has and a hash of them:

````md
table: 'data/team.csv'
<!-- table 2 rows · 3f2a9c -->
| name | role     |
| ---- | -------- |
| Ada  | engineer |
| Lin  | design   |
````

Edit the table, like changing a cell or adding a row, and Raindown writes its rows back to the file. Edit the file and the table's written again. The hash is of the rows as they were when the table and the file last matched, so Raindown can tell which one changed. When both did, neither is written, and the comment reads `<!-- table conflict · 3f2a9c -->` until they match again. To keep the file's rows instead, delete the comment, or empty the table. A `|` in a cell is written as `\|`, and a line break in one as a space.

With `total: true`, a bold row below the table sums each column whose cells are all numbers or blank, to the most decimal places any of them has, and labels the first column Total unless it's numbers too:

````md
table: 'data/sales.csv' total: true
<!-- table 2 rows · 40ec83 -->
| item      | units | price    |
| --------- | ----- | -------- |
| Tea       | 3     | 1.5      |
| Cake      | 2     | 2.25     |
| **Total** | **5** | **3.75** |
````

The total is worked out again whenever the table's written, and never written to the file, so edit the rows above it, or add rows below it, and it sums them.

Formula cells in the file, like `=SUM(B)` by its column's letter or `=sum(Price)` by its header, show their values in the table, summing the numbers in the column below its header, like a spreadsheet, and leaving out other formulas. Case doesn't matter, in `SUM` or the column, so `=Sum(b)` and `=sum(PRICE)` work too. A formula naming a column that doesn't exist shows as it's written, like other formulas, so you can keep typing it. When the table's edits are written back, a formula cell still showing its value keeps its formula, so type a new formula or value into one to replace it. To edit its formula instead, delete the spaces around its value, so it's no longer lined up with its column, and the formula shows in its place, like `=SUM(B)`. It keeps showing until you change it, ignoring spaces, and then it's written to the file and shows its value again. Adding or deleting rows above a formula cell moves it, so check it's still a formula afterwards.

### Endpoints

Put an `endpoint:` directive above a curl snippet and Raindown writes the response in a code block below it, typed by its content type, after a comment of its status, how long it took and the date it was fetched:

````md
endpoint:
```sh
curl https://httpbin.org/uuid
```
<!-- response 200 · 142 ms · 2026-10-14 -->
```json
{
  "uuid": "4c9d6a2e-…"
}
```
````

Bare, in a [Raindown file](#raindown-files) (`.rd`), a Markdown file with `raindown: true` front matter, or with `--bare`, it ends at the next blank line, like other bare blocks.

Endpoints only run when you pass `-x` (or `--execute`), and then only the ones whose response block is missing or empty. Without it, Raindown never sends a request, so opening a file is safe. In the terminal UI, `x` or `[Run]` runs just the endpoint you pick, replacing its response.

```sh
raindown api.md -x
raindown watch api.md -x
```

Be careful which files and folders you run Raindown on with `-x`. It runs every endpoint in the files it opens or watches, including files added to a watched folder later, so only use it on files you've read or trust, as you would before running `make` in a repo. Requests go out from your machine, so a snippet can reach anything it can, like servers running on it at `localhost` and services on your private network. With [variables](#endpoint-variables) it can send your environment variables, like API keys, wherever its URL points.

To refresh a response, empty its code block, and its fetched date, status and time are updated too. They're in an HTML comment, so they're hidden on the page, but anyone reading the file or the HTML source, people or agents, can tell how fresh the example is and whether it worked. The snippet runs with the `curl` binary but not through a shell, so pipes, redirects and `$VARIABLES` aren't supported, but [variables](#endpoint-variables) are. Curl is limited to HTTP requests, values can't read files (`-d @body.json`), and other options like `-o`, `-F` or `-K` are rejected. Redirects aren't followed, so `-L` is rejected too, and so are link-local addresses, like the cloud metadata service at `169.254.169.254`, which can give out a server's credentials. Raindown also runs curl without your `~/.curlrc`.

#### Endpoint variables

Like Postman or Bruno, a snippet can use variables, like `{base_url}` and `{token}`, and use one response in the next request. Values come from the file's front matter, then the project's environment, then earlier responses. `{env.NAME}` is the environment variable `NAME`, so secrets stay out of your files.

Environments go in `.raindown/environments.yml`, and an environment's values can read environment variables too:

```yaml
local:
  base_url: http://localhost:3000
staging:
  base_url: https://staging.example.com
  token: '{env.STAGING_TOKEN}'
```

The first environment is used unless you pass `--env` or set `RAINDOWN_ENV`:

```sh
raindown api.md -x --env staging
```

Put secrets in `.raindown/environments.local.yml`, which adds to and overrides `environments.yml`, environment by environment, and which the `.gitignore` that `raindown init` creates leaves out of git. Its values and `{env.NAME}` are secret, so when a response or error echoes one, Raindown writes its placeholder, like `{token}`, instead, while later requests that read the response still get the value. Values shorter than four characters aren't hidden, as they'd match anywhere.

Name an endpoint with `as:` and later snippets in the file can read its response, like `{login.token}` or `{users.0.id}` in JSON, or the whole response as `{login}`:

`````md
endpoint: as: login
```sh
curl -d 'user=ada' {base_url}/login
```

endpoint:
```sh
curl -H 'Authorization: Bearer {login.token}' {base_url}/me
```
`````

The response is read from the file, so running one endpoint on its own, like from the terminal UI, still uses earlier responses. Each word of the snippet is filled in after it's split, so a value can't add options, and placeholders without a value, like the braces in JSON, are left as they are.

#### Checking responses

Like tests in Postman or Bruno, an endpoint can say what its response should be, with `status:` and a [LowType](https://github.com/low-rb/lowtype) `schema:`:

`````md
endpoint: status: 200 schema: Schema[id: Integer, email: String | nil, tags: Array[String]]
```sh
curl {base_url}/users/1
```
`````

A key whose type allows `nil` may be missing, and keys a schema doesn't name are allowed. Nest schemas, like `Schema[address: Schema[city: String]]`, and check lists, like `Array[Schema[id: Integer]]`, but write them with `Schema[]`, not `{}`, which reads as a variable. The schema is read without running it, so only types, values, `|` and `[]` on `Array`, `Hash`, `Schema`, `Enum` and `Status` are allowed.

For a bigger schema, name it with `schema:` and its fields below it, indented, then give its name to the endpoints below it. A key with no type holds the more indented fields under it:

`````md
<!-- schema: User
  id: Integer
  email: String | nil
  address:
    city: String
-->

endpoint: schema: User
`````

The name can be quoted, like `'User'`, or not. A name can go inside a type too, like `schema: Array[User]`, and in schemas below it, like `author: User`. In a [Raindown file](#raindown-files), write `schema: User` bare, with its fields ending at the first line that isn't indented, and it shows in bold with its fields below it. In comments it's left out of the HTML.

Schemas in `.raindown/schemas.rd`, written bare the same way, can be named by every file's endpoints, and a file's own schemas with the same name win.

Every response in the file is checked, whether it's just run or was already there, by the status in the comment above it, so checking needs no requests. Failures are listed with where they are, like `api.md:3: id: expected Integer, received "1"`. `--html` lists them and exits with `1`, so CI can check that your docs still match your API, watching lists them as the file's written back, and the terminal UI shows them after a run. To check a live API, empty the response blocks first, then run with `-x`.

### Nodes

> [!NOTE]
> A node is how a directive is built and a component is how it's rendered. Nodes that start with a capital letter like `Changelog:` are components. Nodes like `if:` are templating.

#### Ruby Components

Use [LowNodes](https://github.com/low-rb/lownode) to write Markdown into the file with `rewrite`, and render HTML into the page with `render`. Bare or in comments, a node writes back, with `rewrite`. In `<{ }>` it's write-in, with `render` alone. Put them in a `.raindown` folder in your project root and Raindown [loads](https://github.com/low-rb/dirload) them automatically:

```ruby
# .raindown/changelog.rb
class Changelog < LowNode
  def initialize(limit: 5)
    @releases = Release.all.first(limit)
  end

  # Written into the Markdown.
  def rewrite
    @releases.map { |release| "- **#{release.version}** #{release.summary}" }.join("\n")
  end

  # Rendered into the HTML, and all that renders in <{ }>. Without it, the HTML of the Markdown above is rendered.
  def render
    "<section class=\"changelog\">...</section>"
  end
end
```

A node block names the node and its props, and Raindown writes the node's Markdown into it whenever the file is rendered:

```md
<!-- Changelog: limit=3 -->
- **1.2.0** Bare directives close themselves
- **1.1.0** Track fetched dates
<!-- :Changelog -->
```

In a [Raindown file](#raindown-files) it can also use bare syntax, with the Markdown straight below it up to the next blank line (a bare node block can't write blank new lines):

```md
Changelog: limit=3
- **1.2.0** Bare directives close themselves
- **1.1.0** Track fetched dates
```

Props can be quoted text, numbers, `true`, `false` or [variables](#variables) like `author.name`, written `limit=3` or `limit: 3`. Bare or in comments, a word is text, like `folder: notes`, and a variable is in braces, like `{author.name}`, while in `<{ }>` a word is a variable. Like YAML, unquoted text after `name:` runs up to the next prop, so `title: Hello world limit: 3` has two, while after `name=` it's one word. Quote text with a word and colon inside, like `title: 'Read this: now'`, and words that read as values, like `'1.10'` or `'true'`. Quoted text means the same in every way a directive's written. A variable is the data it holds, so a list stays a list. A value before the props, like `'data.csv'` in `chart: 'data.csv' format: 'columns'`, is passed to the node's `initialize` as its argument. `rewrite` and `render` can also take the keywords `document:` (the Markdown being rendered), `metadata:` and `bare:`, and `rewrite` can take `written:`, the lines it wrote last time, and they get the ones they ask for. A node takes edits when its `rewrite` takes `written:`: like `table:`, it can see what was changed since it wrote, and write that back to its source. In `<{ }>` a node is write-in: a self-closing `<{ Changelog }>`, a bare `:Changelog`, or a `<{ Changelog: }>` block only renders, with `render`, never `rewrite`, and writes nothing into the file. A block's Markdown between its tags is its input, which `render` gets as `slot:`, in HTML. In `<{ }>` a node's props can be loop variables, like `<{ Changelog limit=n }>` in a `for:`, and it can be in another node's slot. A self-closing node can also be `<{ :Changelog }>`, which a lowercase name needs, like `<{ :toc }>`, as `<{ toc }>` is a variable. A node needs a `render` to be write-in, and raises without one. Raindown's own nodes have one, and `<{ table: }>` shows its file without writing to it. A `Raindown::Node` renders its `rewrite` as HTML, unless its `rewrite` takes `written:`, which needs a `render` of its own, so rendering a page never writes to a node's source. Raindown keeps one instance of each node and its props while it runs, so `rewrite` and `render` can share what they work out, like the releases above. A name only starts a node block when it's a loaded LowNode with a `rewrite` method, so other text like `Note:` is left alone. Nodes run your project's code whenever Raindown renders the file.

#### JavaScript Components

JavaScript can be used for custom components too, as a `.js` or `.mjs` file in the same `.raindown` folder that exports a class with `rewrite`, and optionally `render`:

```js
// .raindown/changelog.mjs
import { Release } from "../lib/release.mjs"

export class Changelog {
  constructor({ limit = 5 }) {
    this.releases = Release.all().slice(0, limit)
  }

  // Written into the Markdown. Can be async.
  rewrite({ document, metadata, bare }) {
    return this.releases.map((release) => `- **${release.version}** ${release.summary}`).join("\n")
  }

  // Rendered into the HTML, and all that renders in <{ }>. Without it, the HTML of the Markdown above is rendered.
  render({ html }) {
    return `<section class="changelog">...</section>`
  }
}
```

It is used like any component like `<!-- Changelog: limit=3 -->`. Its props come first in the constructor, then the value before them, if any. Its methods get the context as one object, where `metadata` is `{ root, files }`, with each file's front matter and path but not its content. A Ruby node of the same name is used instead. JavaScript Components need [Node.js](https://nodejs.org) 22 or later on your `PATH`, which runs them in one process of their own, and only projects that have them need it. What they log goes to stderr. They can't subclass Raindown's own nodes, like `Chart`, so they can't replace `toc:`, `list:` or `chart:`.

#### Markdown Components

A Markdown file in `.raindown` named like a component, like `BookCard.md`, is a component too, with no code. Its props are its variables, and its front matter is their defaults:

`````md
---
rating: 0
---

**{title}** · {rating}/5
`````

`BookCard: title: The Dispossessed rating: 5` writes `**The Dispossessed** · 5/5` below it. A value before the props, like `'Dune'` in `BookCard: 'Dune'`, is `{value}`, and templating like `<{ if: }>` and `<{ for: }>` works in it. Raindown reads the file each time it writes the component, so a change shows on the next render. A Ruby or JavaScript component of the same name is used instead.

### Config

A project can keep settings in `config.yml` in its [`.raindown`](#nodes) folder.

Code blocks are highlighted in the HTML. For a site that highlights code in the browser instead, like with [Prism](https://prismjs.com), turn it off and each code block gets a language class, like `<pre><code class="language-ruby">`:

```yaml
# .raindown/config.yml
highlight_code: false
```

### VS Code

The [VS Code extension](vscode/) highlights syntax and previews Raindown files with the [editor server](#editor-server), or `--stdin` with a Raindown from before it, rendering as you type. In Markdown files it highlights `<{ }>` directives and renders them in the built-in Markdown preview.

### Obsidian

The [Obsidian plugin](https://github.com/rainpour/raindown-obsidian) writes back to your notes as you save them, like `raindown watch`, with the [editor server](#editor-server), or `raindown NOTE --stdin --rewrite`, which prints the note as it would be written back without writing it. So tables of contents, components and `list:` fill in as you write, in plain Markdown that reads the same outside Obsidian. Endpoints only run from its **Run the endpoints in this note** command. If Raindown isn't installed, it offers to download the standalone binary.

### Editor server

Editors keep Raindown loaded with `raindown server`, so a render doesn't start Ruby again each time: the first takes about a second, and the ones after it a few milliseconds. It says it's ready, then answers one JSON request a line on stdin, in order, on stdout:

```
{"ready":true,"version":"0.10.0"}
{"id":1,"path":"/notes/a.md","markdown":"# A\n\n<!-- toc: -->\n<!-- :toc -->\n","rewrite":true}
{"id":1,"output":"# A\n\n<!-- toc: -->\n- [A](#a)\n<!-- :toc -->\n","warnings":[]}
```

With `"rewrite": true`, it answers like `--stdin --rewrite`, with `"execute": true` like `-x`, and otherwise with HTML, like `--stdin`. `"bare": true` is like `--bare`. An error is answered as `{"id":1,"error":"raindown: /notes/a.md: ..."}`. Each project renders in a process of its own, which starts again when a file in its `.raindown` folder changes, so its components, config and schemas are never stale. On Windows, which can't fork, start the server again after changing them.

### Standalone binaries

Each [GitHub release](https://github.com/rainpour/raindown/releases) has a standalone `raindown` executable for macOS, Linux (glibc and musl) and Windows, built with [Tebako](https://github.com/tamatebako/tebako). Ruby is bundled inside, so nothing else needs to be installed, except on Alpine and other musl distros, which need `libgcc` and ncurses (`apk add libgcc ncurses-libs`). Other Linux binaries use the system's ncurses, which most distros include.

To build one for your own machine, [install Tebako](https://github.com/tamatebako/tebako#installation) and run:

```sh
bundle exec rake tebako  # writes pkg/raindown-<version>-<platform>
```
