## 2026-10-30T07:59:19Z · diagram

```diagram
                                      Raindown CLI
                                           │
        ┌──────────────────────────────────┼──────────────────────────────────┐
        │                                  │                                  │
  raindown [PATH]                 raindown watch [PATH]          raindown FILE --html / --stdin
  terminal UI (default)           no UI                          render once
  no terminal? watches instead    Watcher::Supervisor (folder)   PreRenderer → Commonmarker
        │                         Watcher::FileWatcher (file)    → HTML to stdout or a file
        │                                  │                     (VS Code preview: --stdin)
        │                                  │
        ▼                                  ▼
╭──────────────────────────────╮   ╭─────────────────────────────────╮
│  TUI                         │   │  Watching                        │
│                              │   │                                  │
│  Screen  ── curses, 12 fps ──│   │  Watcher.listen (Listen, skips   │
│    │ keys, clicks, hover     │   │  node_modules, build, tmp…)      │
│    ▼                         │   │     │ saved / added / removed    │
│  Navigator                   │   │     ▼                            │
│    ├─ files · endpoints      │   │  Watcher.changes                 │
│    ├─ pages: 📊 Dashboard    │   │     ├─ nodes changed → restart   │
│    │         🎭 Feelings     │   │     └─ Markdown saved → update   │
│    │         🌀 Blueprints   │   │     │  (a thread per project)    │
│    ├─ views → Renderers      │   ╰─────┼────────────────────────────╯
│    │  → Layout (one frame)   │         │
│    └─ Saves ── Watcher.listen│         │
│         (queued, each tick)  │         │
╰──────────────┬───────────────╯         │
               │                         │
               ▼                         ▼
       ╭────────────────────────────────────────────────╮
       │  Workers: a process per project (fork)         │
       │  each loads its own .raindown nodes, so two    │
       │  projects' nodes of the same name stay apart   │
       │                                                │
       │   TUI::Project            Watcher::Project      │
       │   outline · charts ·      update(path)          │
       │   endpoints · write_back                        │
       ╰───────────────────────┬────────────────────────╯
                               ▼
               ╭───────────────────────────────╮
               │  Rewriter                      │
               │  Document → directives <{ }>   │
               │   toc · files · tables ·       │
               │   chart · stat · endpoint ·    │
               │   project nodes (LowNode,      │
               │   Antlers)                     │
               │  --bare  → bare directives     │
               │  -x      → run empty endpoints │
               ╰───────────────┬───────────────╯
                               ▼
                   README.md  docs/*.md  *.rd
                   written back on save, then the
                   save of that changes nothing

   .raindown/
   ├─ config.yml · nodes (*.rb, *.rbx)
   ├─ feelings.csv · memories.csv ◀── Code feelings (1–5)
   │       └──▶ CodeHealth / CodeDebt stats ──▶ README
   └─ diagrams.md ◀── raindown diagrams ◀── Claude Code Stop hook
           └──▶ 📐 Diagrams page
```

## 2026-10-30T08:38:56Z · mockup

```mockup
──────────────────────────┬────────────────────── Directive Zoo ────────────────
                          │   ┌─ TOC ──────┐  ┌─ Chart ────┐  ┌─ CodeDebt ─┐
                          │   │  (\_/)     │  │   ▁▃▅█     │  │   $ $ $    │
                          │   │  (o.o)     │  │   grazing  │  │   hoarding │
                          │   │ seen 12×   │  │ seen 8×    │  │ seen 1×    │
                          │   └────────────┘  └────────────┘  └────────────┘
                          │   ┌─ Shout ────┐  ┌─ endpoint ─┐  ┌─ ??? ──────┐
                          │   │  \(O)/     │  │  ~~~>      │  │   empty    │
                          │   │  LOUD      │  │ restless   │  │ "Greeting" │
                          │   │ seen 2×    │  │ seen 5×    │  │ escaped!   │
                          │   └────────────┘  └────────────┘  └────────────┘
                          │   Please don't feed the bare directives.
```

## 2026-10-30T10:12:56Z · mockup

```mockup
 2 of 2 · 2026-10-30 08:38 UTC · mockup · main @ 8b61e6f
 files: lib/raindown/tui.rb · spec/raindown/tui_spec.rb   +2 commits since
```

## 2026-10-30T11:28:33Z · mockup

```mockup
╭──────────────────────────────╮   ╭─────────────────────────────────╮
│  TUI                         │   │  Watching                        │
│  Screen  ── curses, 12 fps ──│   │  Watcher.listen (Listen, skips   │
│    │ keys, clicks, hover     │   │  node_modules, build, tmp…)      │
│    ▼                         │   │     ▼                            │
│  Navigator                   │   │  Watcher.changes                 │
│    └─ Saves ── Watcher.listen│   │     └─ Markdown saved → update   │
╰──────────────┬───────────────╯   ╰─────┬───────────────────────────╯
               ▼                         ▼
       ╭────────────────────────────────────────────────╮
       │  Workers: a process per project (fork)         │
       ╰────────────────────────────────────────────────╯
```

## 2026-10-30T11:28:33Z · mockup

```mockup
╭──────────────────────────────╮   ╭─────────────────────────────────╮
│                              │   │                                  │
│  def take_events(drawn_at) ──│   │  def self.listen(directory, &)   │
│    │                         │   │                                  │
│    ▼                         │   │     ▼                            │
│  def next_step(event)        │   │  def self.changes(paths, root: … │
│    └─ def take = Array.new(… │   │     └─                           │
╰──────────────┬───────────────╯   ╰─────┬───────────────────────────╯
               ▼                         ▼
       ╭────────────────────────────────────────────────╮
       │  def for(path) = self[Projects.root(path) || r…│
       ╰────────────────────────────────────────────────╯
```
## 2026-11-02T05:38:40Z · mockup

`MenuBox` (`lib/raindown/tui/menu_box.rb`) draws the project menu: the box that drops down from the path in the header when you press `p` or click the path:

```mockup
🌧  Raindown  ~/dev ▾ › Dashboard
             ┌──────────────────────┐
             │ All projects       ✓ │
             │ ~/dev/raindown       │
             └──────────────────────┘
```

## 2026-11-04T11:35:37Z · diagram

**New blueprint** (`data/blueprints.md`): the same README before and after saving.

```diagram
╭─ README.md ────────────────╮        ╭─ README.md ────────────────╮
│ # My project               │        │ # My project               │
│                            │        │                            │
│ <!-- CodeDebt: -->         │        │ <!-- CodeDebt: -->         │
│ <!-- :CodeDebt -->         │        │ +1.0 · 2 fixes             │
│                            │        │ <!-- :CodeDebt -->         │
│ <!-- toc: -->              │  save  │                            │
│ <!-- :toc -->              │ ─────▶ │ <!-- toc: -->              │
│                            │        │ - Install                  │
│ ## Install                 │        │ - Usage                    │
│ ## Usage                   │        │ <!-- :toc -->              │
│                            │        │                            │
│                            │        │ ## Install                 │
│                            │        │ ## Usage                   │
╰────────────────────────────╯        ╰────────────────────────────╯
```

## 2026-11-07T07:41:08Z · diagram

**Today, each run replaces the last:**

```diagram
 GitHub API ───▶ endpoint: ───▶ open issues: 6
                                only the latest, yesterday's is gone
```

## 2026-11-07T07:41:08Z · mockup

**With a reservoir, each run adds a row:**

```mockup
 GitHub API          Stripe API         Your API        channels
     ┊                   ┊                  ┊
     ┊                   ┊                  ┊           one drop per run
     ▼                   ▼                  ▼
 ┌────────────┐     ┌────────────┐     ┌────────────┐
 │            │     │            │     │            │
 │▒▒▒▒▒▒▒▒▒▒▒▒│     │            │     │▒▒▒▒▒▒▒▒▒▒▒▒│   reservoirs fill
 │▒▒▒▒▒▒▒▒▒▒▒▒│     │▒▒▒▒▒▒▒▒▒▒▒▒│     │▒▒▒▒▒▒▒▒▒▒▒▒│   up over time
 └─────┬──────┘     └─────┬──────┘     └─────┬──────┘
   issues.csv        revenue.csv        signups.csv     plain files
       ┊                  ┊                  ┊
       ▼                  ▼                  ▼
    chart:             table:             chart:        release on demand
```

## 2026-11-07T09:30:33Z · diagram

Here's a mock-up of a single frame. It's a terminal game, so it's drawn the way it would look there. It uses your real commits from this week, and each repo is a channel they fall down:

```diagram
 RAINDOWN · catch your week           score 1,240   streak x4   ♥ ♥ ♥
 ─────────────────────────────────────────────────────────────────────
   raindown        plugin          vscode          docs
      ┊               ┊               ┊               ┊
      ┊               ●               ┊               ┊
      ┊            410acdd            ┊               ┊
      ●               ┊               ┊               ◆
   e3918aa            ┊               ┊            v0.16.1
      ┊               ┊               ✖               ┊
      ┊               ┊            conflict           ┊
      ┊               ●               ┊               ┊
      ┊            7bb54ec            ┊               ┊
      ┊               ┊               ┊               ┊
      ┊            \_____/            ┊               ┊
 ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒
 ← → move    space dash                 Tue · 14 drops caught · 3 missed
```

## 2026-11-07T09:30:33Z · mockup

At the end, you get a summary of your real work:

```mockup
 ─────────────────── WEEK OF NOV 2 ───────────────────

   Caught     63 of 71 drops        Best streak    x12
   Releases   ◆ ◆ ◆                 Hail dodged    4

   Mon  ▂▂
   Tue  ▅▅▅▅▅▅
   Wed  ▂
   Thu  ▃▃▃
   Fri  █████████      "A proper storm."

   Wettest repo: raindown      Longest drought: 2 days
 ───────────────────────────────────────────────────────
```

## 2026-11-07T09:50:38Z · diagram

A pre-commit hook has problems, though. It would delete the output from your working file on every commit, and `--no-verify` skips it. A **git clean filter** fixes the first of those: git stores the stripped version, while your file keeps its output on disk. `nbstripout` does the same for Jupyter notebooks.

```diagram
 on disk                         in git
 ─────────────────────           ─────────────────────
 <!-- Stripe: -->                <!-- Stripe: -->
 | Nov | $14,100 |      ──▶      <!-- :Stripe -->
 <!-- :Stripe -->
```

## 2026-11-07T09:50:38Z · mockup

Markdown has no CSS, so what's written into the file can't have real borders. There are two options:

```mockup
 written into the file            rendered in HTML
 ╭─────────────────────╮
 │ Contents            │          a styled card with
 │ Reading             │          real, clickable links
 │ Finished            │
 ╰─────────────────────╯
```

