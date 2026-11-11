# TODO

## Endpoint response freshness

A response only refreshes when its code block is emptied, so once written it stays, and a year-old response looks the same as one fetched today. Readers, and agents especially, can't tell whether an example still holds. Responses now record the date they were fetched (`<!-- raindown:fetched 2026-10-14 -->`), but nothing checks they still match.

**Check mode.** `raindown file.rd --check` re-runs every endpoint without writing, and exits non-zero listing the responses that no longer match, for CI. Needs a way to ignore fields that change every request (ids, timestamps), for example an `ignore:` list on the directive or a JSON path list.

## Code feelings

Ideas for the feelings screen, roughly most useful first.

1. **Jump to the next unfelt method.** Felt methods go blank, so late in the week the grid is mostly empty, and the arrows step through cells there's nothing left to do in. `n` and `N` could jump to the next or previous unfelt method in reading order.
2. **Undo the last feeling.** One wrong key, like `1` instead of `2`, notes a feeling straight away, and the only way back is feeling it again. `u` could remove the last row from `feelings.csv` and select its method again.
3. **Click a bin to feel the selected method.** The bins are drawn, but clicking them does nothing, as they have no click events. With hover already working, Code feelings could be used with the mouse alone.
4. **The hovered method's name in the status line.** The code box doesn't follow the mouse, so while hovering, the status line could show `lib/text.rb:62 · Text#segments_between`, and "This week's code to feel" otherwise.
5. **Esc collapses an expanded code box.** Esc only does something while a note's being typed.
6. **How many are left, beside "39% refined".** Like "12 left", which says more near the end of the week.
7. **A scroll hint when an expanded box pushes rows off the grid.** A faint `↑` or `↓` at the grid's edge, so it's clear it's scrolled.
8. **A resize during the celebration** can pick a bigger batch, with unfelt methods, while the rain or waffle carries on. Not picking again until the celebration's over would fix it.

## Tebako boot time

The packed binary is slow to start. A plain note takes about 1.1s, against 0.35s from source. A table or chart adds about 0.5s more.

The cause is macOS's malware scan (XProtect). Each native extension is scanned every time the app starts, because Tebako copies it to a new random folder each time. Each scan takes about 0.4s. Raindown loads three: `commonmarker`, `prism`, and `strscan` (which `csv` loads). Ruby's own loading is fast. See [tamatebako/tebako#1026](https://github.com/tamatebako/tebako/issues/1026).

The fix is [3769344](https://github.com/tamatebako/tebako/commit/3769344). It keeps each extension in the same folder, so macOS only scans it once. It's not in a release yet. 2.8.76 came out just before it, and isn't any faster.

**When a release has the fix:**

1. Download it: `gh release download vX -R tamatebako/tebako -p 'tebako-X-macos-x86_64*' -D tmp/tebako-bin`. Check the `.sha256` file matches, and run `chmod +x` on it.
2. Build with it: `TEBAKO=tmp/tebako-bin/tebako-X-macos-x86_64 mise exec -- bundle exec rake tebako`. The rake task pins runtime 0.16.32. A new Tebako may need a newer one. (Tebako 2.8.76 can't use the 0.17 runtimes, which come with Ruby 3.4.12.)
3. Time `--version`, a plain note, a `chart:` and a `table:` with `--html`. Run each once first, then time a few runs. Compare with `~/.local/bin/raindown`. It should be about 0.4s faster for each extension a note loads.
4. To time each extension, run the binary with `RUBYOPT=-r<script>`, where the script times each `require`. Before the fix, `strscan.so` alone took 0.44s.
5. Check that lazy loading still helps. Loading `csv` and `prism` at startup didn't help with 2.8.76. With the fix, a plain note that doesn't load them should still be fastest.

**Watch out: a rebuild can run old code.** Tebako caches each package's files in `~/.tebako/payloads`, by name. If you rebuild the same version, it keeps using the old cached files, and only says so in `~/.tebako/journal.log`. Delete `~/.tebako/payloads/raindown-*` before timing a rebuild. Or add a hash of the package to `payload_name` in `rakelib/tebako.rake`.
