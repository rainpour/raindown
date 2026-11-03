# Changelog

All notable changes to this project will be documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
Minor features that don't break backwards compatibility are released as patches.

## Unreleased

### Added

- Obsidian's `[[wikilinks]]`, which render as links to the file they name, and `backlinks:`, which writes the files that link to this one
- `--html -` prints the HTML to stdout, like `--html`
- Endpoint responses keep their status and time in their fetched comment, like `200 · 142 ms`
- Endpoints check their responses with `status: 200` and a LowType `schema: Schema[id: Integer]`, and `--html` fails on failures
- Named schemas, with `schema: User` and indented fields below it, for endpoints like `schema: Array[User]`, and shared ones in `.raindown/schemas.rd`
- Secrets in `.raindown/environments.local.yml`, which `raindown init` gitignores, and which responses and errors never write back

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
