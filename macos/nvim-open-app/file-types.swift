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

// Claimed so a folder dropped on the app opens there, but never made the
// default: double-clicking a folder should still open it in Finder.
let skipAsDefault: Set<String> = [
    "public.folder",
]

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
func claimedTypes() -> [UTType] {
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
    for name in skipAsDefault {
        types[name] = nil
    }

    return types.keys.sorted().map { types[$0]! }
}

func setDefault(app: URL) {
    let app = app.resolvingSymlinksInPath().standardizedFileURL

    // macos puts up a confirmation dialog for every single type it is asked
    // about, so skip the ones already pointing at us: the first run is a wall
    // of dialogs, a rerun asks nothing.
    var pending: [UTType] = []
    var unchanged = 0
    for type in claimedTypes() {
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
    fail("usage: file-types.swift declare <app> <name> <bundle-id> | set-default <app>")
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
default:
    fail("unknown command '\(args[0])'")
}
