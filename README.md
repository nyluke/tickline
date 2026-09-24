# Tickline

A fast, native Markdown *reader* for macOS — like Typora, minus the editor.

![Tickline showing a Markdown document with headings, lists, a block quote, a code block, and a table](docs/screenshot.png)

## What it does

- Renders CommonMark + GFM (tables, task lists, strikethrough) into a native
  `NSAttributedString` — no WebKit, no JavaScript, no bundled Chromium.
- Opens fast: it's just AppKit text rendering, so cold launch is well under
  a second.
- Sets itself as the default app for `.md` / `.markdown` / `.mkdn` files.
- Light/dark appearance toggle (toolbar button or the Appearance menu),
  independent of your system setting — defaults to light.
- Copying a selection puts HTML on the clipboard alongside RTF, so pasting
  into Gmail or another browser-based app keeps headings, lists, links,
  code, and tables instead of dropping to plain text.

It intentionally doesn't edit or save — it's a viewer, not an IDE.

## Install

### Option 1: download the app

Grab the `.dmg` from the [latest release](https://github.com/nyluke/tickline/releases/latest),
open it, and drag Tickline into Applications.

Tickline isn't notarized (no Apple Developer Program membership behind
this project) and is only ad-hoc code-signed, so Gatekeeper will refuse
to open it — and on current macOS, right-click → Open does **not**
bypass this the way it does for apps that are Developer ID–signed but
just not notarized. The reliable fix is one Terminal command, run once
after moving it to Applications:

```sh
xattr -cr /Applications/Tickline.app
```

Then open it normally. You'll also want to set it as the default `.md`
handler yourself: right-click a Markdown file → Get Info → "Open with:"
→ Tickline → **Change All...**.

### Option 2: build from source

Requires the Swift toolchain (Xcode or just the Command Line Tools) and
[Homebrew](https://brew.sh) for [`duti`](https://github.com/moretension/duti)
(used to set the default file handler; the script falls back to printing
manual instructions if `duti` isn't installed).

```sh
git clone https://github.com/nyluke/tickline.git
cd tickline
./Scripts/install.sh
```

This builds a release binary, assembles `Tickline.app`, ad-hoc code-signs
it, installs it to `/Applications`, and sets it as the default handler for
Markdown files automatically — no Gatekeeper prompt, since it's built
locally rather than downloaded.

Other scripts: `./Scripts/build-app.sh` just builds `build/Tickline.app`
without installing it; `./Scripts/make-dmg.sh` packages a release `.dmg`.

## iPhone app

There's an iOS counterpart under [`iOS/`](iOS) that shares the Markdown
parsing/rendering code with the Mac app (see below) but has its own
UIKit-based text view and app shell. It opens one `.md` file at a time —
tap a Markdown file in Files, Mail, AirDrop, etc. and it opens in
Tickline, the same way the Mac app works.

To run it on your own iPhone:

1. Install Xcode (from the App Store) if you haven't already — a plain
   Swift toolchain isn't enough for iOS, since device installs require
   Xcode's code signing.
2. Open `iOS/Tickline.xcodeproj`.
3. Select the `Tickline` target, go to **Signing & Capabilities**, and
   pick your Apple ID under **Team** (add it first via Xcode → Settings →
   Accounts if it's not listed).
4. Plug in your iPhone, select it as the run destination, and hit Run.

Like the Mac app, this isn't going through TestFlight or the App Store,
so with a free Apple ID the install expires after about 7 days — just
re-run from Xcode to refresh it. A paid Apple Developer Program
membership avoids that if you'd rather not repeat the step.

## How it's built

The Mac app has no Xcode project of its own — just
[Swift Package Manager](Package.swift) and a hand-written `Info.plist`.
The parsing/rendering core lives in the `TicklineKit` library target
(`Sources/TicklineKit`), shared with the iOS app: `MarkdownDocument`
loads the file, a `MarkupVisitor` (`MarkdownRenderer.swift`) built on
[`swift-markdown`](https://github.com/swiftlang/swift-markdown) walks the
parsed tree and builds a styled `NSAttributedString`, and a
`PlatformFont`/`PlatformColor`/`PlatformImage` typealias layer
(`PlatformTypes.swift`) is the only thing standing between that and
AppKit vs. UIKit. Each platform then supplies its own text view — a
custom `NSTextView` on the Mac (`Sources/Tickline/MarkdownTextView.swift`)
and `UITextView` on iOS (`iOS/Tickline/MarkdownTextView.swift`) — that
draws the full-width code block cards and block-quote bars itself, since
`NSAttributedString.backgroundColor` only paints behind glyphs.

The renderer also tags each block and inline run with its Markdown
structure (`MarkdownBlockContext.swift`), which is what lets
`MarkdownHTMLExporter` turn an arbitrary selection back into nested HTML
when the Mac app copies it.

## Known limitations

- On iOS, tables render as an aligned monospace grid rather than a real
  ruled table. (The Mac app lays them out as real tables.) When a Mac
  window is too narrow for every column to fit its longest word, the
  columns holding the longest words or paths get narrowed until those
  words break across lines.
- Remote (`http`/`https`) images show as a clickable link rather than
  loading inline, to keep launch fast and dependency-free.
- `.mdown` / `.mkd` extensions are owned by Typora's own file type on
  systems that have it installed, so they aren't remapped to Tickline.

## License

[MIT](LICENSE)
