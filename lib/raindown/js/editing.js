// Editing Markdown as it's typed, as Raindown would write it back, which an editor does at once, so it never waits for
// Raindown: lining up tables, the same as Raindown's TableFormatter, and what Enter, Tab and Option or Alt and Enter
// do in a table's cell, like in a spreadsheet, and finding Raindown's directives, like a table: block's, in Markdown.
// The Obsidian plugin and the app both edit with it, as raindownEditing, each in its own editor. A plain script, like
// services.js, so each host can put it before its own code, which is a CommonJS module too, where it's required.
const raindownEditing = (() => {
  // A comment on its own line that isn't a directive, which straight below a directive is its node's comment, like
  // table:'s <!-- 2 rows · 3f2a9c -->, as Raindown reads it.
  const BLOCK_COMMENT = /^\s*<!--(?!\s*(?::[A-Za-z]|[A-Za-z][\w-]*(?:::[A-Z]\w*)*:)).*-->\s*$/;

  // Highlighting, like the VS Code extension's: directives in comments, like <!-- toc: --> and the end tag <!-- :toc -->,
  // in <{ }>, and bare ones where they'd write back, like toc:, with the self-closing :toc. Not in code or front matter.
  const NAME = String.raw`[A-Za-z][\w-]*(?:::[A-Z]\w*)*`;

  const COMMENT_DIRECTIVE = new RegExp(String.raw`<!--\s*(?:(:${NAME})|(${NAME}:))(.*?)-->`, 'g');

  const ANTLERS = /<\{(.*?)\}>/g;

  const BARE_SELF_CLOSING = /^( {0,3})(:toc)[ \t]*$/;

  const BARE_OPEN = new RegExp(String.raw`^( {0,3})(${NAME}:)(?=[ \t]*$|[ \t]+\S)`);

  // Strings, {variables}, numbers, :flags, props like folder: or limit=, and words.
  const ARGUMENT = /"(?:[^"\\]|\\.)*"|'(?:[^'\\]|\\.)*'|\{[A-Za-z_][\w.]*\}|(?<![\w:])-?\d+(?:\.\d+)?\b|(?<![\w:]):[A-Za-z_][\w-]*|[A-Za-z_][\w-]*(?::(?![\w:])|=)|[A-Za-z_][\w.-]*/g;

  // The highlighted parts of a note, in order, as { from, to, type }, where type is a class like cm-raindown-name.
  function directiveTokens(text, { bare = false } = {}) {
    const front = /^---\n([\s\S]*?)\n---(?:\n|$)/.exec(text);
    const bareHere = bare || /^raindown:\s*true\s*$/m.test(front?.[1] ?? '');
    const tokens = [];
    let offset = front ? front[0].length : 0;
    let fence = null;

    for (const line of text.slice(offset).split('\n')) {
      const marker = /^ {0,3}(`{3,}|~{3,})/.exec(line)?.[1];
      if (fence) {
        if (marker?.[0] === fence[0] && marker.length >= fence.length) fence = null;
      } else if (marker) {
        fence = marker;
      } else {
        tokens.push(...lineTokens(line, { bare: bareHere }).map((token) => ({ ...token, from: token.from + offset, to: token.to + offset })));
      }
      offset += line.length + 1;
    }

    return tokens.sort((a, b) => a.from - b.from);
  }

  function lineTokens(line, { bare }) {
    const code = [...line.matchAll(/(`+)[^`]*?\1/g)].map((match) => [match.index, match.index + match[0].length]);
    const tokens = [];
    const add = (from, to, type) => {
      if (!code.some(([start, end]) => from < end && to > start)) tokens.push({ from, to, type });
    };

    for (const match of line.matchAll(COMMENT_DIRECTIVE)) {
      const name = match[1] ?? match[2];
      const start = match.index + match[0].indexOf(name);
      add(start, start + name.length, match[1] ? 'end' : 'name');
      argumentTokens(match[3], start + name.length, { antlers: false }, add);
    }
    for (const match of line.matchAll(ANTLERS)) {
      const end = match.index + match[0].length;
      add(match.index, match.index + 2, 'delimiter');
      argumentTokens(match[1], match.index + 2, { antlers: true }, add);
      add(end - 2, end, 'delimiter');
    }
    if (!bare) return tokens;

    const selfClosing = BARE_SELF_CLOSING.exec(line);
    const open = BARE_OPEN.exec(line);
    if (selfClosing) add(selfClosing[1].length, selfClosing[1].length + selfClosing[2].length, 'self-closing');
    if (open) {
      const end = open[1].length + open[2].length;
      add(open[1].length, end, 'name');
      argumentTokens(line.slice(end), end, { antlers: false }, add);
    }

    return tokens;
  }

  // The row of a table the cursor's in, with the |+ rows carrying it on: the lines it spans, the column the cursor's in,
  // the line its table starts on, whether it's the header or the delimiter row below it, and the line of the row below
  // it, or null outside a table's rows.
  function tableRowAt(lines, { line, ch }) {
    const row = (number) => /^\s*[|+]/.test(lines[number] ?? '') && lines[number].trim();
    let start = line;
    while (start > 0 && row(start - 1)) start--;
    if (!row(line) || !isTableStart(lines, start)) return null;

    const lead = lines[line].search(/[|+]/);
    if (ch <= lead) return null;

    let [first, last] = [line, line];
    while (first > start + 2 && CONTINUATION.test(lines[first])) first--;
    while (CONTINUATION.test(lines[last + 1] ?? '')) last++;
    const header = line === start;
    const below = header ? start + 2 : last + 1;
    const column = [...lines[line].slice(lead + 1, ch).matchAll(/(?<!\\)\|/g)].length;
    return { start, first, last, column, header, delimiter: line === start + 1, next: row(below) ? below : null };
  }

  // Whether the table starting on the line is a table: block's, below its directive and its comment.
  function underTableDirective(text, lines, start, options) {
    const above = BLOCK_COMMENT.test(lines[start - 1] ?? '') ? start - 1 : start;
    const directiveEnd = lines.slice(0, above).join('\n').length;
    return tableFiles(text, options).some(({ at }) => at === directiveEnd);
  }

  // What Enter does to the cell the cursor's in, in a table: block's table, each cell of a row on its own: 'collapse' one
  // shown in full on |+ rows, or 'expand' one cut to fit, ending in an ellipsis, deleting it so Raindown shows its full
  // text. Elsewhere it's null, and Enter only moves to the row below.
  function cellToggle(text, lines, row, options) {
    if (!underTableDirective(text, lines, row.start, options)) return null;

    const below = lines.slice(row.first + 1, row.last + 1).map(tableCells);
    if (below.some((cells) => cells[row.column])) return 'collapse';
    if (tableCells(lines[row.first])[row.column]?.endsWith('…')) return 'expand';
    return null;
  }

  // Whether the cursor's in a table: block's fixed column, like |=====|, or on the |+ rows of a cell in one.
  function inFixedCell(text, cursor, options) {
    const lines = text.split('\n');
    const row = tableRowAt(lines, cursor);
    if (!row || row.delimiter || !fixedColumn(tableCells(lines[row.start + 1])[row.column] ?? '')) return false;

    return underTableDirective(text, lines, row.start, options);
  }

  // What Enter does to the cell at the offset, for its hint.
  function cellToggleAt(text, offset, options) {
    const lines = text.split('\n');
    const row = tableRowAt(lines, positionOf(text, offset));
    return row && cellToggle(text, lines, row, options);
  }

  // Where a cell is in a row's line, from after the pipe before it to the pipe after it, or null past its last.
  function cellBounds(line, column) {
    const lead = line.match(/^[ \t]*\|\+?/)?.[0].length ?? 0;
    const pipes = [...line.matchAll(/(?<!\\)\|/g)].map(({ index }) => index).filter((index) => index >= lead);
    const from = column === 0 ? lead : pipes[column - 1] + 1;
    if (Number.isNaN(from)) return null;

    return { from, to: pipes[column] ?? line.length };
  }

  // Where the cursor goes to be at the end of a cell's text in a row's line: after its last letter, or inside it when
  // it's empty.
  function cellEndIn(line, column) {
    const cell = cellBounds(line, column);
    if (!cell) return line.length;

    return cell.from + Math.max(1, line.slice(cell.from, cell.to).trimEnd().length);
  }

  // An empty row for the row's table, indented like it, which the table lines up.
  function emptyRow(lines, row) {
    const cells = tableCells(lines[row.start + 1]).map(() => '');
    return `${lines[row.first].match(/^[ \t]*/)[0]}| ${cells.join(' | ')} |`;
  }

  // A row and its |+ rows with one column's cell joined back onto the row's line, its parts joined with spaces, leaving
  // the other columns' cells as they are, and the |+ rows nothing's left on out.
  function collapsedColumn(rows, column) {
    const cells = rows.map(tableCells);
    const indent = rows[0].match(/^[ \t]*/)[0];
    const joined = cells.map((row) => row[column] ?? '').filter(Boolean).join(' ');
    const first = cells[0].map((cell, index) => (index === column ? joined : cell));
    const below = cells.slice(1).map((row) => row.map((cell, index) => (index === column ? '' : cell))).filter((row) => row.some(Boolean));
    return [`${indent}| ${first.join(' | ')} |`, ...below.map((row) => `${indent}|+${row.join(' | ')} |`)];
  }

  // The change Enter makes in a table's row, like in a spreadsheet: done with the cell, moving the cursor to the end of the
  // same cell in the row below, which is added in the last row. In a table: block's table, it expands a cell cut to fit,
  // staying in it, and collapses one shown in full, joining its text on the |+ rows back onto its row first, so Raindown
  // clips it again. As offsets, with what it toggled, or null outside a table's rows.
  function enteredCell(text, offset, options) {
    const lines = text.split('\n');
    const row = tableRowAt(lines, positionOf(text, offset));
    if (!row) return null;

    const toggle = cellToggle(text, lines, row, options);
    if (toggle === 'expand') return expandedCell(text, lines, row);

    const rows = lines.slice(row.first, row.last + 1);
    const kept = toggle === 'collapse' ? collapsedColumn(rows, row.column) : rows;
    // In the last row, a row's added below it to move to, like a spreadsheet's next row.
    const added = row.next === null && !row.header ? [emptyRow(lines, row)] : [];
    const insert = [...kept, ...added].join('\n');
    const from = offsetOf(text, { line: row.first, ch: 0 });
    const to = offsetOf(text, { line: row.last, ch: lines[row.last].length });
    const after = text.slice(0, from) + insert + text.slice(to);
    const target = row.next === null ? row.first + kept.length - 1 + added.length : row.next - (rows.length - kept.length);
    const cursor = offsetOf(after, { line: target, ch: cellEndIn(after.split('\n')[target], row.column) });

    return { from, to, insert, cursor, toggle };
  }

  // The change expanding a cell cut to fit: its ellipsis deleted, with the cursor where it was.
  function expandedCell(text, lines, row) {
    const line = lines[row.first];
    const cell = cellBounds(line, row.column);
    const at = offsetOf(text, { line: row.first, ch: line.lastIndexOf('…', cell.to) });
    return { from: at, to: at + 1, insert: '', cursor: at, toggle: 'expand' };
  }

  // Where Tab moves the cursor in a table's row, like in a spreadsheet: to the end of the next cell's text on its line, or
  // the first of the row below, or with back, like Shift and Tab, the previous cell, or the last of the row above. It
  // stays put in the table's last cell, or first, so Tab never splits a row. Null outside a table's rows.
  function tabbedCell(text, offset, { back = false } = {}) {
    const lines = text.split('\n');
    const position = positionOf(text, offset);
    const row = tableRowAt(lines, position);
    if (!row) return null;

    const { line } = position;
    const columns = tableCells(lines[row.start + 1]).length;
    const at = (number, column) => offsetOf(text, { line: number, ch: cellEndIn(lines[number], column) });
    const column = row.column + (back ? -1 : 1);
    if (column >= 0 && column < columns) return at(line, column);
    if (!back) return row.next === null ? at(line, row.column) : at(row.next, 0);

    let above = row.first - 1;
    if (above === row.start + 1) above = row.start;
    while (above > row.start + 2 && CONTINUATION.test(lines[above])) above--;
    return above < row.start ? at(line, row.column) : at(above, columns - 1);
  }

  // The change Option or Alt and Enter makes in a table's cell, like a line break in a spreadsheet: a |+ row below the
  // cursor's row carrying the cell on, with what's after the cursor in it, rather than splitting the row, which would
  // end the table. As offsets, with where the cursor goes, or null outside a table's rows, or in its header or
  // delimiter row.
  function carriedOnCell(text, offset) {
    const lines = text.split('\n');
    const { line, ch } = positionOf(text, offset);
    const row = tableRowAt(lines, { line, ch });
    if (!row || row.header || row.delimiter) return null;

    const { column } = row;
    const current = lines[line];
    const cellEnd = current.slice(ch).search(/(?<!\\)\|/);
    const end = cellEnd === -1 ? current.length : ch + cellEnd;
    const carried = `|+${' | '.repeat(column)}`;
    const cells = tableCells(lines[row.start + 1]).map((_, index) => (index === column ? current.slice(ch, end).trim() : ''));
    const from = offsetOf(text, { line, ch: 0 });
    const insert = `${current.slice(0, ch).trimEnd()} ${current.slice(end)}\n|+${cells.join(' | ')} |`;

    return { from, to: from + current.length, insert, cursor: from + insert.indexOf('\n') + 1 + carried.length };
  }

  // Each table: directive's file, like 'data/books.csv', with where its line ends, for a button to open it there.
  function tableFiles(text, options) {
    const tokens = directiveTokens(text, options);

    return tokens.flatMap((token, index) => {
      if (!/^:?table:?$/.test(text.slice(token.from, token.to))) return [];

      let lineEnd = text.indexOf('\n', token.to);
      if (lineEnd === -1) lineEnd = text.length;
      const data = directiveArgument(text.slice(token.to, lineEnd));
      if (!data) return [];

      return [{ at: lineEnd, data }];
    });
  }

  // The value after a directive's name, like its file, quoted or not, as Raindown reads it, up to any props, like
  // data/books.csv in table: data/books.csv total: true, or table: data/books.csv, total: true, or null without one.
  function directiveArgument(rest) {
    const text = rest.replace(/\s*(?:-->|\}>)\s*$/, '').trim();
    const quoted = /^(["'])(.*?)\1/.exec(text);
    if (quoted) return quoted[2];

    return /^(.*?)(?=(?:,[ \t]*|\s+)\w+(?:=|:\s)|,?\s*$)/.exec(text)[1] || null;
  }

  // In <{ }>, its first word is the directive, like toc: or :toc, and words are variables. Outside, words are text.
  function argumentTokens(text, offset, { antlers }, add) {
    let first = antlers;
    for (const match of text.matchAll(ARGUMENT)) {
      const type = argumentType(match[0], { antlers, first });
      first = false;
      if (type) add(offset + match.index, offset + match.index + match[0].length, type);
    }
  }

  function argumentType(token, { antlers, first }) {
    if (/^["']/.test(token)) return 'string';
    if (token.startsWith('{')) return 'variable';
    if (/^-?\d/.test(token)) return 'number';
    if (token.startsWith(':')) return first ? 'end' : 'flag';
    if (/[:=]$/.test(token)) return first ? 'name' : 'prop';

    return antlers ? 'variable' : null;
  }

  // Whether the cursor's in a table cell starting with =, so a formula that's still being typed.
  function inFormulaCell(line, ch) {
    const start = line.lastIndexOf('|', ch - 1);
    if (!line.trimStart().startsWith('|') || start === -1) return false;

    return line.slice(start + 1, ch).trimStart().startsWith('=');
  }

  // The start of each line of a Markdown table, and its |+ rows, as Raindown's columns only line up in a monospace font,
  // with its header, to show in bold, its delimiter row, to show muted, and its pipes, to show faint, but for those of a
  // row carrying one on, its |+ and pipes, in the accent colour.
  function tableLines(markdown) {
    const lines = markdown.split('\n');
    let offset = 0;
    return lines.flatMap((line, number) => {
      const from = offset;
      offset += line.length + 1;
      if (!/^[ \t]*\|.*\|[ \t]*$/.test(line)) return [];

      const header = isTableStart(lines, number) ? [{ from, to: from + line.length, type: 'table-header' }] : [];
      const delimiter = number > 0 && isTableStart(lines, number - 1) ? [{ from, to: from + line.length, type: 'table-delimiter' }] : [];
      // A row carrying on the one above has its |+ and pipes in the accent colour, so it's plain it's part of that row.
      const type = CONTINUATION.test(line) ? 'table-expansion' : 'table-pipe';
      const pipes = [...line.matchAll(/(?<!\\)\||(?<=^[ \t]*\|)\+/g)].map(({ index }) => ({ from: from + index, to: from + index + 1, type }));
      return [{ from, type: 'table' }, ...header, ...delimiter, ...pipes];
    });
  }

  // Lining up tables as they're typed, the same as Raindown's TableFormatter, so its write-back finds them lined up.
  const DELIMITER_CELL = /^:?[-=]+:?$/;

  // A row carrying on the one above it, starting with |+ in place of a row's "| ", which Raindown joins into its cells.
  const CONTINUATION = /^[ \t\n\v\f\r]*\|\+/;

  const FENCE = /^\s*(```|~~~)/;

  // Ruby's strip, which leaves other spaces, like a no-break space, in the cell.
  const STRIP = /^[ \t\n\v\f\r\0]+|[ \t\n\v\f\r\0]+$/g;

  // East Asian wide and fullwidth letters, and emoji, take two columns, like unicode-display-width's with emoji: :all.
  const WIDE = new RegExp(String.raw`[\u1100-\u115F\u2E80-\u303E\u3041-\u33FF\u3400-\u4DBF\u4E00-\u9FFF\uA000-\uA4CF` +
    String.raw`\uA960-\uA97F\uAC00-\uD7A3\uF900-\uFAFF\uFE30-\uFE4F\uFF00-\uFF60\uFFE0-\uFFE6\u{20000}-\u{3FFFD}\uFE0F\u20E3]` +
    String.raw`|\p{Emoji_Presentation}`, 'u');

  const ZERO_WIDTH = /^[\p{Mn}\p{Me}\p{Cf}]+$/u;

  // Graphemes, where the engine can tell them, or else characters, as in QuickJS, which hasn't got Intl.
  const graphemes = typeof Intl === 'object' && Intl.Segmenter && new Intl.Segmenter();

  function displayWidth(text) {
    let width = 0;
    for (const segment of segmentsOf(text)) {
      if (WIDE.test(segment)) width += 2;
      else if (!ZERO_WIDTH.test(segment)) width += 1;
    }
    return width;
  }

  function segmentsOf(text) {
    if (!graphemes) return Array.from(text);

    return Array.from(graphemes.segment(text), ({ segment }) => segment);
  }

  // How a row's line starts, before its first cell: |+ when it carries on the row above, as wide as a row's "| ".
  function rowLead(line) {
    return CONTINUATION.test(line) ? '|+' : '| ';
  }

  // A row's cells, split on pipes that aren't escaped, without its outer pipes, or the |+ starting a continuation row.
  function tableCells(line) {
    let content = line.replace(STRIP, '');
    const lead = rowLead(line).trimEnd();
    if (content.startsWith(lead)) content = content.slice(lead.length);
    if (content.endsWith('|') && !content.endsWith('\\|')) content = content.slice(0, -1);
    if (!content) return [];

    return content.split(/(?<!\\)\|/).map((cell) => cell.replace(STRIP, ''));
  }

  function isTableStart(lines, index) {
    const [header, delimiter] = [lines[index], lines[index + 1]];
    if (!header.includes('|') || delimiter === undefined || CONTINUATION.test(header)) return false;

    const cells = tableCells(delimiter);
    if (!cells.length || cells.length !== tableCells(header).length) return false;

    return cells.every((cell) => DELIMITER_CELL.test(cell));
  }

  // Whether a column's delimiter cell makes it fixed, like Raindown's TableColumn: equals signs, or one typed into dashes,
  // as fewer of them than dashes, while a dash typed into equals signs makes it widen again.
  function fixedColumn(delimiter) {
    const [equals, dashes] = ['=', '-'].map((sign) => delimiter.split(sign).length - 1);
    return equals > 0 && (dashes === 0 || equals < dashes);
  }

  // A column, like Raindown's TableColumn: its alignment, from its delimiter cell's colons, and its width, that of its
  // widest cell, or as wide as its delimiter when that's equals signs, which is fixed, letting a longer cell run past.
  function tableColumn(delimiter, cells) {
    const fixed = fixedColumn(delimiter);
    // An equals sign typed into dashes isn't part of its width, so it's fixed as wide as it was.
    const typed = delimiter.includes('-') ? delimiter.split('=').length - 1 : 0;
    const width = fixed ? delimiter.length - typed : Math.max(3, ...cells.map(displayWidth));
    const dash = fixed ? '=' : '-';
    let alignment = null;
    if (delimiter.startsWith(':') && delimiter.endsWith(':')) alignment = 'center';
    else if (delimiter.endsWith(':')) alignment = 'right';
    else if (delimiter.startsWith(':')) alignment = 'left';

    return {
      pad(cell) {
        const padding = Math.max(0, width - displayWidth(cell));
        if (alignment === 'center') return ' '.repeat(Math.floor(padding / 2)) + cell + ' '.repeat(Math.ceil(padding / 2));
        if (alignment === 'right') return ' '.repeat(padding) + cell;
        return cell + ' '.repeat(padding);
      },
      delimiterCell() {
        if (alignment === 'center') return `:${dash.repeat(width - 2)}:`;
        if (alignment === 'right') return `${dash.repeat(width - 1)}:`;
        if (alignment === 'left') return `:${dash.repeat(width - 1)}`;
        return dash.repeat(width);
      }
    };
  }

  // A table's lines with each column padded to fit, keeping each row's + when it carries on the row above, or as they
  // were when a row has more cells than its header.
  function alignedTable(table) {
    const indent = table[0].match(/^[ \t\n\v\f\r]*/)[0];
    const [header, delimiter, ...body] = table.map(tableCells);
    if (body.some((row) => row.length > header.length)) return table;

    const rows = [header, ...body.map((row) => [...row, ...Array(header.length - row.length).fill('')])];
    const columns = delimiter.map((cell, column) => tableColumn(cell, rows.map((row) => row[column])));
    const line = (lead, cells) => `${indent}${lead}${cells.join(' | ')} |`;
    const lines = [table[0], ...table.slice(2)].map((original, row) => line(rowLead(original), rows[row].map((cell, column) => columns[column].pad(cell))));

    return [lines[0], line('| ', columns.map((column) => column.delimiterCell())), ...lines.slice(1)];
  }

  // The note with every table lined up, outside code. Like Raindown, one lined up at the very end gets a line break
  // after it.
  function alignTables(markdown) {
    const lines = markdown.split('\n');
    const output = [];
    let inFence = false;
    for (let index = 0; index < lines.length;) {
      if (FENCE.test(lines[index])) inFence = !inFence;
      if (inFence || !isTableStart(lines, index)) {
        output.push(lines[index++]);
        continue;
      }

      let end = index + 2;
      while (end < lines.length && lines[end].includes('|') && lines[end].trim()) end++;
      const table = lines.slice(index, end);
      const aligned = alignedTable(table);
      output.push(...aligned, ...(end === lines.length && aligned !== table ? [''] : []));
      index = end;
    }
    return output.join('\n');
  }

  function offsetOf(text, { line, ch }) {
    return text.split('\n').slice(0, line).reduce((offset, before) => offset + before.length + 1, ch);
  }

  function positionOf(text, offset) {
    const lines = text.slice(0, offset).split('\n');
    return { line: lines.length - 1, ch: lines.at(-1).length };
  }

  // The |+ lines carrying on the table rows a deletion removes the whole of, each with its line break, so they go with
  // their row rather than being left below the row above, which Raindown would read them as carrying on. As ranges in the
  // text before the deletion, which is ranges too.
  function orphanedRows(text, deletions) {
    const lines = text.split('\n');
    const starts = [0];
    lines.forEach((line) => starts.push(starts.at(-1) + line.length + 1));
    const removed = (number) => deletions.some(({ from, to }) => from <= starts[number] && starts[number] + lines[number].length <= to);

    return lines.flatMap((line, number) => {
      if (!line.trim() || !removed(number) || !/^[ \t]*\|/.test(line) || CONTINUATION.test(line)) return [];

      let last = number;
      while (CONTINUATION.test(lines[last + 1] ?? '')) last++;
      const rows = Array.from({ length: last - number }, (_, index) => number + 1 + index).filter((row) => !removed(row));
      return rows.map((row) => ({ from: starts[row], to: Math.min(starts[row + 1], text.length) }));
    });
  }

  return {
    BLOCK_COMMENT, alignTables, carriedOnCell, cellToggleAt, directiveTokens, enteredCell, inFixedCell, inFormulaCell, offsetOf, orphanedRows, positionOf, tabbedCell, tableCells, tableFiles, tableLines
  };
})();

if (typeof module === 'object') module.exports = raindownEditing;
