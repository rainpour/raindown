# Agents

Raindown is a superset of Markdown. Its directives sit between `<{` and `}>`, and some of them write their output into the file. Read this before editing any Markdown here, like `README.md`, or the code that renders it.

## Directives write their own output

Content directives, like `toc:`, `files:`, `chart:`, `endpoint:` and the project's own nodes in `.raindown/`, like `CodeDebt:`, write their output into the Markdown below them, up to their end tag:

```md
<{ CodeHealth: }>
...written by Raindown...
<{ :CodeHealth }>
```

- **Don't edit what's between a content directive and its end tag.** The next time the file is rendered, Raindown writes it again, and your edit is lost.
- **Edit the directive's input instead**, like `<{ files: folder: 'notes' }>`, or the node or data it reads, like a CSV file for a chart, then render the file again.
- An endpoint's response is the exception: empty its code block to fetch it again.

Raindown also lines up the columns of Markdown tables when it writes a file back, so don't worry about aligning them.

Template directives, like `if:`, `for:`, `list:` and variables like `{title}`, don't write anything. The Markdown around them is yours to edit.

In `.rd` and `.raindown` files, and Markdown files with `raindown: true` in their front matter, directives can be bare, on their own line without `<{ }>`, like `:toc`.

## Rendering a file again

Rendering a file writes its directives' output back to it:

```sh
mise exec -- bundle exec bin/raindown README.md --html /dev/null
```

`raindown` and `raindown watch` do this whenever a file is saved, so if one is running, saving the file is enough.

## Files Raindown writes

Don't edit these by hand unless you're asked to:

- `.raindown/feelings.csv` and `.raindown/memories.csv`, which Code feelings writes.
- `.raindown/blueprints.md`, which `raindown blueprints` writes from Claude Code's replies.

## Working on Raindown

Ruby runs through mise:

```sh
mise exec -- bundle exec rspec
mise exec -- bundle exec rubocop
```

The README is Raindown's documentation and is rendered by Raindown itself, so a change to a feature usually means a change to the README too.
