# Launch post drafts

## Show HN

**Title:** Show HN: Tickline – a native, instant-open Markdown reader for macOS

**Body:**

I wanted a way to just *read* Markdown files on my Mac without opening an
editor, and without the ~1s+ launch delay and Electron/WebKit overhead that
comes with most "lightweight" readers. So I built Tickline: it parses
CommonMark + GFM with Apple's swift-markdown and renders straight into a
native NSAttributedString/NSTextView — no WebKit, no JS runtime, no editing
UI at all. Cold launch is under 200ms in my testing.

It's a SwiftUI/AppKit app, built with just Swift Package Manager (no Xcode
project needed), and sets itself as the default handler for .md files.
Light/dark toggle, tables, task lists, code blocks, all rendered natively.

It's free and MIT licensed, and not notarized — Apple Developer Program
membership costs money I didn't want to spend on a hobby project, so the
first launch needs one Terminal command to clear the Gatekeeper quarantine
flag (documented in the README). Building from source avoids that step
entirely.

Repo: https://github.com/nyluke/tickline

Would love feedback, especially from anyone who's fought with TextKit for
custom block rendering (block quotes, code cards) — happy to talk through
how that's done.

## r/macapps

**Title:** [Free] Tickline – a native Markdown reader that opens instantly (no Electron/WebKit)

**Body:**

Made this because I wanted a Typora-like reading experience without the
editor, and without the launch lag of most Electron-based "lightweight"
apps. Tickline is a small native SwiftUI/AppKit app — parses Markdown with
Apple's own swift-markdown library and renders it directly as native text,
so it opens in well under a second.

Features:
- Headings, bold/italic/strikethrough, code blocks, block quotes, ordered/
  unordered/nested/task lists, tables, links, local images
- Light/dark toggle, independent of system setting
- Sets itself as the default app for .md files

It's free and open source. One caveat: it's not notarized (that costs
$99/yr through Apple and this is just a personal project), so the first
open needs one Terminal command — instructions are in the README. If
you'd rather avoid that entirely, building from source with the included
script has no Gatekeeper issue at all.

https://github.com/nyluke/tickline

Feedback / bug reports very welcome — it's brand new.
