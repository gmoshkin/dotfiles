// The file types NvimOpen claims, and the two things macos wants done with
// them. Run by build.sh:
//
//     swift file-types.swift declare <app> <name> <bundle-id>
//         writes them into the bundle's Info.plist, which is what puts the app
//         in Finder's "Open With" menu
//
//     swift file-types.swift set-default <app>
//         makes the app the default for them, i.e. what double-clicking does
//
// and one to run by hand when something opens in the wrong app:
//
//     swift file-types.swift query <app>
//         prints what macos currently answers for each of them. Read-only:
//         changes nothing, asks nothing.
//
// Why Swift and not `duti` or `defaults write`:
//
//     LSSetDefaultRoleHandlerForContentType, which duti uses, has become a
//     no-op for other processes on recent macos. It still returns noErr, so the
//     failure is completely silent -- set public.yaml that way, read it
//     straight back, and it still answers com.apple.dt.Xcode.
//     NSWorkspace.setDefaultApplication (macos 12+) is the supported route and
//     actually reports errors.
//
//     Editing ~/Library/Preferences/com.apple.LaunchServices by hand is not an
//     option either: it is SIP-protected and lsd keeps its own copy in memory.

import AppKit
import UniformTypeIdentifiers

// Types macos already has a UTI for. Claiming these is what gets us offered for
// ordinary text files. public.make-source is here because a Makefile has no
// extension to match on; Dockerfile cannot be caught this way, it is plain
// public.data and claiming that would put us on every binary file on the disk.
let knownTypes = [
    "public.text", "public.plain-text", "public.utf8-plain-text", "public.source-code",
    "public.script", "public.shell-script", "public.xml", "public.json", "public.yaml",
    "public.log", "public.comma-separated-values-text", "public.folder",
    "public.make-source",
]

// Anything whose extension macos does not recognise, so it never gets a real
// UTI: .jai is dyn.ah62d4rv4ge80y2pm and nothing at all is offered for it.
let extensions = [
    "jai", "rs", "c", "h", "cc", "cpp", "cxx", "hh", "hpp", "m", "mm", "go", "py", "rb", "pl",
    "lua", "vim", "el", "scm", "js", "jsx", "ts", "tsx", "css", "scss", "html", "htm", "md",
    "markdown", "rst", "txt", "text", "toml", "yaml", "yml", "json", "xml", "ini", "cfg",
    "conf", "config", "log", "sql", "sh", "bash", "zsh", "fish", "gitignore", "gitconfig",
    "editorconfig", "lock", "diff", "patch", "csv", "tsv", "env", "swift"
]

// Not everything worth declaring is worth becoming the default for. Appearing
// in "Open With" costs nobody anything; becoming the default takes the file type
// away from whatever owns it, system-wide, and the extension lists above are
// written by extension, not by meaning.
func skipReason(for type: UTType) -> String? {
    // Double-clicking a folder should still open it in Finder.
    if type == .folder { return "belongs to Finder" }

    // Whoever holds public.html *is* the default web browser: macos derives the
    // http and https scheme handlers from it. Take it and every link clicked in
    // every app arrives here instead of Safari, and a URL is the one thing
    // nvim-open has nothing to do with. Handing back either half fixes both,
    // they are a single setting:
    //
    //     NSWorkspace.shared.setDefaultApplication(
    //         at: safari, toOpenURLsWithScheme: "http")
    if type == .html { return "this is the default-browser setting" }

    // Wanted anyway, against the rule below. Which way round these go is a
    // judgement about this machine, not something the rule can work out: a .ts
    // here is TypeScript far more often than it is a video stream, and a
    // wireguard .conf is something to edit more often than to import.
    if ["public.mpeg-2-transport-stream", "org.amnezia.amneziavpn.wireguard-config"]
        .contains(type.identifier) { return nil }

    // The rule below is for the extension list, which is written by extension
    // and so gets whatever type macos happens to associate. knownTypes was
    // written by meaning -- public.log does not conform to public.text and is
    // still exactly what we want to open.
    if knownTypes.contains(type.identifier) { return nil }

    // An extension macos has never heard of gets a dynamic type (.jai is
    // dyn.ah62d4rv4ge80y2pm); nothing else claims those, they are ours to take.
    // An extension that resolves to a *real* type it does not share our idea of
    // is somebody else's format wearing a source-file extension: .ts is
    // public.mpeg-2-transport-stream, a video, and .conf belongs to a VPN
    // client. Declaring them is still right -- opening one in nvim on purpose is
    // reasonable -- but double-clicking must keep doing what it did before.
    if !type.isDynamic && !type.conforms(to: .text) {
        return "not a text type"
    }

    return nil
}

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("file-types.swift: \(message)\n".utf8))
    exit(1)
}

// Role Editor because we open files to edit them; rank Alternate to be offered
// as a choice without quietly becoming the handler for every text file on the
// system -- being the default is set-default's business, and revocable.
func declare(app: URL, name: String, bundleID: String) {
    let plistURL = app.appendingPathComponent("Contents/Info.plist")

    guard let data = try? Data(contentsOf: plistURL) else {
        fail("cannot read \(plistURL.path)")
    }
    var format = PropertyListSerialization.PropertyListFormat.xml
    guard var plist = ((try? PropertyListSerialization.propertyList(
        from: data, options: [], format: &format)) as? [String: Any])
    else {
        fail("\(plistURL.path) is not a property list dictionary")
    }

    plist["CFBundleName"] = name
    plist["CFBundleIdentifier"] = bundleID

    // Replacing wholesale: osacompile leaves the droplet's legacy declaration
    // here -- CFBundleTypeExtensions "*" and CFBundleTypeOSTypes "****" --
    // which today's LaunchServices ignores, and which is why the app used to be
    // reachable only through "Other...". Claiming the root UTIs public.item or
    // public.data does not help either: that registers as a wildcard claim and
    // is left out of the menu just the same. Verify with
    //
    //     NSWorkspace.shared.urlsForApplications(toOpen: url)
    plist["CFBundleDocumentTypes"] = [
        [
            "CFBundleTypeName": "Text file",
            "CFBundleTypeRole": "Editor",
            "LSHandlerRank": "Alternate",
            "LSItemContentTypes": knownTypes,
        ],
        [
            "CFBundleTypeName": "Source file",
            "CFBundleTypeRole": "Editor",
            "LSHandlerRank": "Alternate",
            "CFBundleTypeExtensions": extensions,
        ],
    ]

    guard let out = try? PropertyListSerialization.data(
        fromPropertyList: plist, format: format, options: 0)
    else {
        fail("cannot serialize \(plistURL.path)")
    }
    do {
        try out.write(to: plistURL)
    } catch {
        fail("cannot write \(plistURL.path): \(error.localizedDescription)")
    }

    print("declared \(knownTypes.count) types and \(extensions.count) extensions")
}

// Both lists often land on the same UTType -- "txt" and "public.plain-text" are
// one type -- so resolve everything up front and deduplicate by identifier.
func declaredTypes() -> [UTType] {
    var types: [String: UTType] = [:]

    for name in knownTypes {
        guard let type = UTType(name) else { print("\(name): no such type, skipped"); continue }
        types[type.identifier] = type
    }
    for ext in extensions {
        // Unknown extensions have no preferred type; ask for the dynamic one
        // rather than giving up, which is the whole point for .jai
        guard let type = UTType(filenameExtension: ext)
            ?? UTType(tag: ext, tagClass: .filenameExtension, conformingTo: nil)
        else {
            print("\(ext): no type for this extension, skipped"); continue
        }
        types[type.identifier] = type
    }

    return types.keys.sorted().map { types[$0]! }
}

// A type's identifier is not always something you can recognise -- .jai is
// dyn.ah62d4rv4ge80y2pm -- so show the extension macos would give it back.
func describe(_ type: UTType) -> String {
    guard let ext = type.preferredFilenameExtension else { return type.identifier }
    return "\(type.identifier) (.\(ext))"
}

func handlerName(_ url: URL?) -> String {
    guard let url else { return "(none)" }
    // Anything outside /Applications is worth seeing in full: a stale copy in
    // ~/Desktop answering for a type explains a lot of confusing behaviour.
    return url.path.hasPrefix("/Applications/") ? url.lastPathComponent : url.path
}

func query(app: URL) {
    let app = app.resolvingSymlinksInPath().standardizedFileURL
    let types = declaredTypes()
    let width = types.map { describe($0).count }.max() ?? 0

    func line(_ mark: String, _ type: UTType, _ trailer: String = "") {
        let handler = handlerName(NSWorkspace.shared.urlForApplication(toOpen: type))
        let label = describe(type).padding(toLength: width, withPad: " ", startingAt: 0)
        print("  \(mark) \(label)  \(handler)\(trailer)")
    }

    var ours = 0, taken = 0
    print("claimed as default:")
    for type in types where skipReason(for: type) == nil {
        taken += 1
        let mine = NSWorkspace.shared.urlForApplication(toOpen: type)?
            .resolvingSymlinksInPath().standardizedFileURL == app
        if mine { ours += 1 }
        line(mine ? "*" : " ", type)
    }
    print("\(ours) of \(taken) open in \(app.lastPathComponent)")

    // Declared but deliberately left alone, and the URL schemes that follow
    // public.html around. A mistake in the lists above shows up here first: if
    // one of these says NvimOpen, we have taken something we should not have.
    print("\ndeclared, left to their owners:")
    var stolen: [UTType] = []
    for type in types {
        guard let reason = skipReason(for: type) else { continue }
        let mine = NSWorkspace.shared.urlForApplication(toOpen: type)?
            .resolvingSymlinksInPath().standardizedFileURL == app
        if mine { stolen.append(type) }
        line(mine ? "!" : " ", type, "  -- \(reason)")
    }

    print("\nurl schemes (never ours):")
    var stolenSchemes: [String] = []
    for scheme in ["http", "https", "mailto"] {
        let url = URL(string: "\(scheme):\(scheme == "mailto" ? "someone@example.com" : "//example.com")")!
        let handler = NSWorkspace.shared.urlForApplication(toOpen: url)
        let mine = handler?.resolvingSymlinksInPath().standardizedFileURL == app
        if mine { stolenSchemes.append(scheme) }
        print("  \(mine ? "!" : " ") \(scheme)  \(handlerName(handler))")
    }

    // There is no API for "forget my override and go back to the system's
    // choice", so a binding taken by mistake has to be handed to a named app.
    // set-default will not take these again, but it cannot undo them either.
    guard !stolen.isEmpty || !stolenSchemes.isEmpty else { return }
    print("""

        \(stolen.count + stolenSchemes.count) marked ! are ours and should not be, \
        left over from an earlier run. Give each back to the app that owns it:

            NSWorkspace.shared.setDefaultApplication(at: owner, toOpen: type) { print($0) }
            NSWorkspace.shared.setDefaultApplication(at: owner, toOpenURLsWithScheme: s) { print($0) }

        Candidates: NSWorkspace.shared.urlsForApplications(toOpen: type)
        """)
}

func setDefault(app: URL) {
    let app = app.resolvingSymlinksInPath().standardizedFileURL

    // macos puts up a confirmation dialog for every single type it is asked
    // about, so skip the ones already pointing at us: the first run is a wall
    // of dialogs, a rerun asks nothing.
    var pending: [UTType] = []
    var unchanged = 0
    for type in declaredTypes() where skipReason(for: type) == nil {
        let current = NSWorkspace.shared.urlForApplication(toOpen: type)?
            .resolvingSymlinksInPath().standardizedFileURL
        if current == app { unchanged += 1 } else { pending.append(type) }
    }

    if pending.isEmpty {
        print("all \(unchanged) types already open in \(app.lastPathComponent), nothing to do")
        return
    }
    print("""
        \(unchanged) types already set, changing \(pending.count) \
        -- macos will ask to confirm each one
        """)

    var failures = 0
    let group = DispatchGroup()
    let lock = NSLock()

    for type in pending {
        group.enter()
        NSWorkspace.shared.setDefaultApplication(at: app, toOpen: type) { error in
            lock.lock()
            if let error {
                print("\(type.identifier): FAILED -- \(error.localizedDescription)")
                failures += 1
            }
            lock.unlock()
            group.leave()
        }
    }
    group.wait()

    print("\(pending.count - failures) of \(pending.count) types now open in \(app.lastPathComponent)")
    if failures > 0 {
        // Handing types to another app only gets as far as the ones that app
        // itself claims, and nothing besides us wants a .jai
        fail("\(failures) types could not be changed, they are unchanged")
    }
}

let args = Array(CommandLine.arguments.dropFirst())
guard args.count >= 2 else {
    fail("""
        usage: file-types.swift declare <app> <name> <bundle-id>
               file-types.swift set-default <app>
               file-types.swift query <app>
        """)
}

let appURL = URL(fileURLWithPath: args[1])
guard FileManager.default.fileExists(atPath: appURL.path) else {
    fail("no app bundle at '\(appURL.path)'")
}

switch args[0] {
case "declare":
    guard args.count == 4 else { fail("declare needs <app> <name> <bundle-id>") }
    declare(app: appURL, name: args[2], bundleID: args[3])
case "set-default":
    setDefault(app: appURL)
case "query":
    query(app: appURL)
default:
    fail("unknown command '\(args[0])'")
}
