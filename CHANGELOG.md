# Changelog

All notable changes to this project will be documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
Minor features that don't break backwards compatibility are released as patches.

## 0.20.0

### Added

- `image:` writes a Markdown image of a file or a URL, with a `width:` in characters for the HTML and editors that draw images in text
- `grid:` writes a frame of equal cells, written again from itself as you edit it, which can hold images by reference
- A grid's cells wrap their text onto their row's next lines, keeping the spaces typed between words, or fit to it with `cell: :fit`
- A grid's width comes from its rules unless `width:` keeps it, and a block starting with a rule, like `+---+`, is a bare grid where bare directives work
- Raindown's own directives work in a grid's cells, writing their output into the cell's lines below them
- `weather:` writes a week's forecast from Open-Meteo, a card a day, where you are or in a place you name, and in a code project draws the branches not merged into main
- `world:` writes a map of the world, with the night where it is now, which the app paints with the cities' lights
- `painting:` writes a different painting from the Rijksmuseum each day, which the app shows in a gilded frame
- A node can rasterize what an app shows behind its text, as a scene the app paints or a raster of pixels, and so can a JavaScript Component
- Raindown's services, the web, a project's files, a cache and git, for Ruby nodes as `raindown:` and JavaScript Components as `raindown`, which an app can answer itself with `Services.host=`
- A rule of `^` above a block takes it to the page's top and left edges, with a `<` before each line
- `kind: code` or `kind: notes` in a project's `config.yml` says what it's for

### Changed

- JavaScript Components run in QuickJS, inside Raindown, so they no longer need Node.js, and can import their own files by their paths
- Raindown starts faster, loading its own directives, and libraries like `uri` and unicode-display_width, the first time they're used

### Fixed

- A directive that can't run, like a typo such as `grid: 80`, keeps what it wrote below its warning, rather than losing it

## 0.19.0

### Added

- `Raindown.render` with `commonmark: false` evaluates templates and writes nodes without Commonmarker, for an app that renders Markdown itself, like Obsidian's reading view
- An endpoint's request is sent through `Curl.fetcher` when it's set, without curl, for runtimes without processes, like WebAssembly
- A host in place of NodeJS can run JavaScript Components, set with `JSNodes.host=`
- An editor watching the files can give Raindown the front matter it's read and which files changed, rather than Raindown reading every note for each `list:`

### Changed

- `toc:` finds headings in the Markdown as it's written, so it's quick enough to write back as you type and sees the headings nodes below it write
- Commonmarker, sockets and `csv` load only when they're needed, so writing back starts faster

### Fixed

- A chart that gives its own points, like a project's commits, no longer warns that it has no file

## 0.18.0

### Added

- Fixed-width table columns, with equals signs in the delimiter, like `| ==== |`
- Typing `=` into a column's dashes fixes it at its width, and `-` into its equals signs widens it again
- `table:` cuts cells to fit a fixed column with `…`, keeping their full text in the file
- Deleting a cell's `…` shows its full text, and typing `…` or `...` into it cuts it again
- Rows starting with `|+` carry on the row above, in any table
- A node's `rewrite` can take `comment:` and return `Raindown::Written`, for a comment below its directive

### Changed

- `table:`'s comment no longer starts with "table", like `<!-- 2 rows · 3f2a9c -->`

### Fixed

- Adding or deleting rows above a formula cell keeps its formula

## 0.17.2

### Added

- `table:` makes its CSV or TSV file when it isn't there yet, from the table written below it, or else one to fill in

### Fixed

- A comma between a directive's values reads like a space, like `table: data.csv, total: true`, rather than as part of the file's name
- `table:` and `chart:` without a value say what they need, and their messages are `> [!WARNING]` alerts too
- A directive that can't run, like one with more or fewer values than it takes, or a node that raises, writes why in its place, as a `> [!WARNING]` alert, so the rest of the file still writes back, rather than stopping it with Ruby's error. Its line's in the warning printed or given to editors
- Editing a table keeps its file's line endings and byte order mark, and leaves empty cells empty, rather than `""`
- A byte order mark, like Excel's, no longer shows in a table or a chart's labels

## 0.17.1

### Fixed

- `raindown server` no longer stops on an unexpected error, like a broken link in `.raindown`, which editors showed as "Raindown stopped"

## 0.17.0

### Added

- `skeleton: true` keeps a file's directives in git, but not what they write, with `raindown skeleton` to set it up and `raindown skeleton --check` for CI

## 0.16.1

### Fixed

- Writing a table again no longer changes a CSV cell with a line break, and editing another cell keeps it
- A file with front matter that can't be read no longer stops `list:` in other files, and a warning names it
- A note in a folder of an Obsidian vault without a `.raindown` folder now finds the whole vault, for `list:`, `table:` and `chart:`
- `list:` with an `order:` no longer fails when files have values of different types
- `list:` links a file without a title by its name, rather than its whole path
- `table:` and `chart:` no longer read or write files outside the project
- `llms.txt` uses `list:` rather than the old `files:`, and writes directives that write into the file in comments

## 0.16.0

### Changed

- `toc:` leaves out a file's title, a single `#` heading at its start, when there are headings below it

## 0.15.0

### Fixed

- A note with a table no longer crashes the server for an editor opened from the Dock (like Obsidian)
- The terminal UI on a folder of projects like `~/dev` no longer writes back to files outside them

### Changed

- An Obsidian vault below a folder Raindown's watching is left alone, as its plugin runs its own Raindown process

### Added

- `table:` with `total: true` sums its columns of numbers in a bold row below it
- `table:` rewrites `=sum(b)` and `=sum(price)` formula cells into calculated values

## 0.14.0

### Changed

- **Breaking:** a node's `replace` is `rewrite`, in Ruby and JavaScript nodes, as it rewrites what the node wrote into the file, and a node in `<{ }>` is write-in, which only renders
- **Breaking:** `files:` is `list:`, one node that writes its links bare or in comments, like `<!-- list: folder: 'notes' -->`, renders them with `<{ :list folder: 'notes' }>`, and repeats its template for each file in `<{ list: page folder: 'notes' }>` ... `<{ :list }>`, which can filter by any tag, like `tags: 'ruby'`, and sort by any metadata, like `order: :created_at`. A project's `Files` node is a `List` node, like `class List < Raindown::List`
- A node in `<{ }>` is write-in: it only renders, with its `render`, never its `rewrite`, and gets the Markdown between its tags, as HTML, as `slot:`. A node with only `rewrite`, like `<{ Changelog }>`, raises until it has a `render`
- `list:`, `chart:`, `table:`, stats and Markdown components render in `<{ }>`, and `<{ table: }>` shows its file without writing to it
- A node in `<{ }>` renders in the template pass, so its props can be loop variables, like `<{ Changelog limit=n }>` in a `for:`, it can be in another node's slot, and a component like `<{ Card }>` gets every prop, like any node, so one it doesn't take is an error
- In `<{ }>` a name with a colon is always a node, so `<{ :app_name }>` is a self-closing tag rather than a translation, which is `{:app_name}`, and a capitalized name without one, like `<{ Card }>`, is self-closing too
- A node whose `rewrite` takes `written:`, so takes edits back to its source, needs its own `render` to be write-in, so rendering never writes to its source
- A component with only `render`, like `<{ Card }>`, renders like any node in `<{ }>`: one instance for its props, with the `document:`, `metadata:` and `bare:` it asks for. A node's HTML renders where it is, so its headings are in the table of contents, unless its `render` takes the page's `html:`, like the TOC's

## 0.13.0

### Changed

- An endpoint's `<!-- response 200 · 142 ms · 2026-10-14 -->` comment goes between its curl snippet and its response, in place of `<!-- raindown:fetched 2026-10-14 · 200 · 142 ms -->` below the response
- A bare `endpoint:` holds the lines straight below it, up to the next blank line, like a bare node block

### Added

- The terminal UI shows Raindown's rain cloud while it loads
- `table:` writes a CSV or TSV file as a Markdown table, and writes edits to the table back to the file
- A node's `replace` can take `written:`, the lines it wrote last time
- `Pages.new(eager: true)` reads every file's front matter straight away, for an app like Raindeer that needs all of it

## 0.12.0

### Changed

- `raindown init` clones [raindown-init](https://github.com/rainpour/raindown-init), with the CodeDebt and CodeHealth nodes, and a first blueprint of how Raindown works
- Feelings, memories and blueprints are kept in `.raindown/data/`, so move them there from `.raindown/`

## 0.11.0

### Added

- An [Obsidian plugin](https://github.com/rainpour/raindown-obsidian) which writes back to notes as they're saved
- `raindown server` keeps Raindown loaded so the Obsidian plugin and the VS Code extension render in milliseconds rather than booting Ruby each time
- `raindown FILE --stdin --rewrite` prints the Markdown from stdin as it would be written back to FILE, for editors
- Support `[[wikilinks]]` syntax which renders links to the file they name
- Markdown Components like `.raindown/BookCard.md`, which write their Markdown with their props as variables without code
- `--html -` prints the HTML to stdout, like `--html`
- Endpoint responses keep their status and time in their fetched comment (`200 · 142 ms`)
- Endpoints check their responses with `status: 200` and a LowType `schema: Schema[id: Integer]`
- `--html` fails on failures
- Named schemas with `schema: User` and indented fields below it, for endpoints like `schema: Array[User]` or shared ones in `.raindown/schemas.rd`
- Secrets in `.raindown/environments.local.yml` which `raindown init` gitignores

### Changed

- **Breaking:** in bare directives and ones in comments an unquoted word is text, like `files: folder: notes`, and only a word in braces is a variable, like `chart: {stats}`, while in `<{ }>` it's still a variable
- Unquoted text after `name:` runs up to the next prop, like YAML, so `title: Hello world limit: 3` has two props
- Text a directive can't read as a prop, like `world` in `tag=a world`, is an error rather than left out

## 0.10.0

### Added

- Endpoint placeholders like `{token}` from front matter, `.raindown/environments.yml` and `env`, chosen with `--env NAME`
- Endpoints named with `as:` pass their response to later endpoints, like `{login.token}`

### Changed

- **Breaking:** endpoints only run with `-x` or a TUI Run, and `endpoint: :x` is gone
- **Breaking:** nested paths read keys, indices and a few safe methods, like `{tags.first}` and `{title.upcase}`, with Antlers 1.4
- Endpoint snippets refuse link-local addresses, like cloud metadata, and `-L`

### Fixed

- Loops over a hash, like `<{ for: name, url in: links }>`

## 0.9.1

### Changed

- A folder of projects like `~/dev` only opens Raindown projects, and finding them skips the folders `.gitignore` files

### Fixed

- Choosing a project filters Code feelings and Blueprints

## 0.9.0

### Added

- JavaScript Components, in `.js` and `.mjs` files in `.raindown`

## 0.8.0

### Added

- HTML comment support for hidden directives (`<!-- toc: -->` and `<!-- :toc -->`)
- Blueprints!

### Changed

- Template directives, like `if:`, `for:` and `list:`, are only written in `<{ }>` (never bare)
- `hide_directives` is gone from `config.yml`, as comment directives are always hidden
- `raindown` opens the terminal UI, rather than `raindown tui`, and `raindown watch` watches
- The terminal UI watches its folder like `raindown watch`, writing back to each Markdown file as it's save

## 0.7.0

### Added

- `raindown tui` teleports with `/`: a search of every file, heading, directive and endpoint, matched as you type
- `chart:` keeps only the last rows with `tail:`, like `tail: 12`, so the Dashboard can follow a file that grows
- A project's stats, nodes that are a `Raindown::Stat`, write one big number in block digits above a label, and show on the Dashboard as cards like charts
- `raindown tui` has Code feelings, under the Dashboard in the files or with `f`: a screenful of random files a week, sort how each function or method makes you feel into frolic, hope, numb, woe, dread or malice,
  noted down in `.raindown/feelings.csv`, moving to `.raindown/memories.csv` once its code changes, and open it in your editor or ask Claude Code to fix it
- `raindown tui` highlights code with Rouge: directives' bodies in the outline, endpoints' responses and Code feelings' code

### Changed

- `raindown tui`'s text is periwinkle where the terminal has 256 colours, apart from the title, in cornflower blue with no background, and including the line between the panes
- `raindown tui`'s title has two spaces after the rain cloud

## 0.6.0

### Added

- `raindown tui` opens on a Dashboard, at the top of the files, showing every chart in the project drawn from its data
- `raindown tui` lists every endpoint below the files, by its request, with its method in colour,
- `Raindown::Document::Directive#body` is the lines inside a directive, like an endpoint's request and response
  and opens one beside them with its URL, a button to run it, and its response

### Changed

- `raindown tui` starts with its folders folded
- `raindown tui` shows the projects inside its folder too, each with its own nodes in a process of its own, like watching.
  They're marked 🌧 in the files, and the Dashboard shows each project's charts under its path.
  The header's path, or `p`, opens a list of the projects, which narrows the files and the Dashboard to one
- `raindown tui`'s title reaches the right edge, with the same rain cloud as the projects in the files

### Fixed

- `Raindown::Document` works when it's required on its own, without the rest of Raindown loaded first
- `raindown tui` no longer crashes in a terminal narrower than 32 columns
- `raindown tui` expands a directive to everything inside it, so an endpoint shows its request as well as its response
- `raindown tui` draws repeated characters, like a bar chart's █, in terminals like Ghostty with macOS's ncurses,
  which drew them as ?

## 0.5.1

### Added

- `raindown: true` in a Markdown file's front matter allows bare directives, like the `.rd` extension or `--bare`

### Changed

- The examples' intros say how to watch and render them, and the Markdown example uses `raindown: true`

## 0.5.0

### Added

- `raindown DIRECTORY`, or `raindown` for the current directory, watches every project in it with a `.raindown` folder
- Each project's nodes load in a process of their own, and reload when they change
- `Raindown::Document.parse(markdown).headings` reads a file's headings with their level, text and line
- `Raindown::Document#directives` reads a file's nodes and endpoints, with their lines and the lines they write back
- `raindown tui [PATH]` browses a project's files and outlines in the terminal, folds directives, runs endpoints
  and opens the editor at a line

### Changed

- Raindown depends on the curses gem, which compiles against ncurses, so Linux needs its headers to install the gem
  (like `libncurses-dev` or `ncurses-dev`). Alpine and other musl distros need `ncurses-libs` to run the binary
- Watching only writes back to files, without writing HTML
- `--html [OUTPUT]` renders HTML once, replacing `--once` and `-o`

## 0.4.0

### Added

- `raindown init` creates a `.raindown` folder with a `config.yml`
- `raindown --version`

### Fixed

- Errors in a file show as one line instead of a backtrace, and `RAINDOWN_DEBUG=1` shows the backtrace
- An error in a file no longer stops `raindown FILE` watching it
- Standalone binaries of the same minor version, like 0.3.0 and 0.3.1, shared a cached payload and warned on every run
- Standalone binaries remove earlier releases' payloads from `~/.tebako`

### Changed

- Remove the nokogiri dependency, which made the gem and standalone binaries much larger
- Escape HTML with `CGI.escapeHTML` rather than loading erb
- Standalone binaries are compressed with DwarFS, and leave out gem archives, other Rubies' native builds, sources, signatures and tests

## 0.3.0

### Added

- Support charts
- Support antlers node arguments

## 0.1.0

### Added

- First release
