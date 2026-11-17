// An action an input took, like a rasterize button's, taken in a host at once, so it shows straight away, as
// Raindown::Action takes it, which takes it again as it writes the note back, and has the last word: props set on the
// directive on a line, counted from 0, like { zoom: 9 } for a map's zoom: 8, each written where the directive has it,
// as it'd be typed, or in a grid's cell, by the column it starts at, after its |. A prop the directive hasn't got, or a
// line that isn't one, leaves the Markdown as it was. Its patterns are NodeBlocks', which spec/raindown/action_spec.rb
// checks it reads as Raindown::Action does. A plain script, not a module, like services.js, so each host can put it
// before its own code.
function raindownAfterAction(markdown, { line, column = null, set }, { bare = false } = {}) {
  // Nodes::BUILT_INS, then a project's own nodes' names, which are capitalized.
  const NAME = String.raw`(?:toc|list|chart|table|image|grid|weather|[A-Z]\w*(?:::[A-Z]\w*)*)`
  const UNQUOTED = String.raw`.+?(?=(?:,[ \t]*|[ \t]+)\w+(?:=|:[ \t])|,?[ \t]*$)`
  const PROP = String.raw`(\w+)(?:=|:[ \t]+)("[^"]*"|'[^']*'|(?<==)\S+?(?=,?(?:\s|$))|${UNQUOTED})`
  const ARG = new RegExp(String.raw`^("[^"]*"|'[^']*'|[^\s"']${UNQUOTED}|[^\s"'])(?:,\s*|\s+|$)`)
  // Each directive's start, up to its props, and its props, in the order NodeBlocks tries them.
  const DIRECTIVES = [
    String.raw`^( {0,3}<\{\s*${NAME}:\s+)(.*?)\s*\}>[ \t]*$`,
    String.raw`^( {0,3}<!--\s*${NAME}:\s+)(.*?)\s*-->[ \t]*$`,
    String.raw`^( {0,3}<\{\s*(?::|(?=[A-Z]))${NAME}\s+)(.*?)\s*\}>[ \t]*$`
  ]
  const BARE_DIRECTIVES = [String.raw`^( {0,3}${NAME}:[ \t]+)(.*?)[ \t]*$`, String.raw`^( {0,3}:${NAME}[ \t]+)(.*?)[ \t]*$`]
  // A component's bare directive, by its capitalized name, which works anywhere, as NodeBlocks::COMPONENT_DIRECTIVES.
  const COMPONENT = String.raw`[A-Z]\w*(?:::[A-Z]\w*)*`
  const COMPONENT_DIRECTIVES = [String.raw`^( {0,3}${COMPONENT}:[ \t]+)(.*?)[ \t]*$`, String.raw`^( {0,3}:${COMPONENT}[ \t]+)(.*?)[ \t]*$`]

  const lines = markdown.split('\n')
  const text = lines[line]
  if (text === undefined) return markdown

  // Where the directive is in the line: all of it but a line break's \r, or its cell, up to the next |, without the
  // spaces around it.
  let [from, to] = [0, text.replace(/\r$/, '').length]
  if (column !== null) {
    const cell = text.slice(column).split('|')[0]
    from = column + cell.length - cell.trimStart().length
    to = from + cell.trim().length
  }
  let patterns = [...DIRECTIVES, ...COMPONENT_DIRECTIVES]
  if (bare || column !== null) patterns = [...DIRECTIVES, ...BARE_DIRECTIVES]
  const match = patterns.map((pattern) => text.slice(from, to).match(new RegExp(pattern))).find(Boolean)
  if (!match) return markdown

  // Where each prop's value is in the line, by its name, after a value that's the node's argument when it comes first.
  const props = match[2]
  const at = from + match[1].length
  let start = props.match(ARG)?.[0].length ?? 0
  if (new RegExp(`^${PROP}`).test(props)) start = 0
  const values = {}
  for (const found of props.slice(start).matchAll(new RegExp(PROP, 'g'))) {
    const end = at + start + found.index + found[0].length
    values[found[1]] = [end - found[2].length, end]
  }
  if (!Object.keys(set).every((name) => name in values)) return markdown

  // Each value typed over where the prop's was, from the last, so where the others are doesn't move.
  const typed = (value) => {
    if (value === null) return 'nil'
    if (typeof value !== 'string') return String(value)
    if (!value.includes("'")) return `'${value}'`
    if (value.includes('"')) throw new Error(`Can't write ${value} as a prop, as it has both kinds of quote`)
    return `"${value}"`
  }
  const spans = Object.entries(set).map(([name, value]) => [...values[name], typed(value)]).sort(([a], [b]) => b - a)
  lines[line] = spans.reduce((edited, [begin, end, value]) => edited.slice(0, begin) + value + edited.slice(end), text)
  return lines.join('\n')
}
