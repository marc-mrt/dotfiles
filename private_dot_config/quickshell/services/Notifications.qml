pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Notifications

// Native replacement for dunst. server registers as the desktop notification
// DBus service on instantiation — dunst's own autostart entry must be
// removed (see hypr/lua/autostart.lua) or the two will fight over the same
// bus name.
//
// history is the single source of truth for what's on screen — there's no
// separate transient-toast vs. persistent-history data, just one array.
// New notifications land at the bottom-right corner (see
// modules/NotificationStack.qml); while the pad is closed a card there
// auto-hides itself 6s after its newest message (see `groups`/expiresAt
// below) but stays in `history` for later review — opening the pad reveals
// everything again, in order. Only clicking a card removes it from history
// outright. dnd only changes the bell's shape
// (bar/components/Notifications.qml) — it doesn't hide anything, same as
// dunst's pause mode never hid history either.
QtObject {
    id: root

    readonly property int historyLimit: 20
    property var history: []
    property bool dnd: false
    property int nextId: 0

    function toggleDnd() {
        dnd = !dnd
    }

    // Grouped by consecutive run, not by app overall — two notifications
    // from the same app with a different app's notification in between get
    // their own separate group cards, matching the order they actually
    // arrived in (history is newest-first, so adjacent entries are
    // chronologically adjacent arrivals). expiresAt is the group's newest
    // message's arrival time + 6s — modules/NotificationStack.qml uses it
    // to auto-hide a card from the corner while the pad is closed (see
    // that file for why "hide" and "drop from history" are different
    // things here).
    readonly property int autoHideMs: 6000
    readonly property var groups: {
        const groups = []
        for (const row of root.history) {
            const last = groups[groups.length - 1]
            if (last && last.groupKey === row.groupKey) {
                // Newest-first iteration: the group's first-seen row is
                // already its newest message, so expiresAt (set below at
                // group creation) must not be overwritten by older rows
                // pushed here — but `id` deliberately IS kept up to date
                // every push, see the comment below.
                last.messages.push(row)
                last.id = row.id
            } else {
                groups.push({
                    // Overwritten above as older rows join this group, so
                    // by the time the group is complete `id` is the
                    // OLDEST message's id — the one that started this
                    // consecutive run, which stays fixed as the group
                    // grows with newer messages. That stability is exactly
                    // what callers tracking per-group state need (see
                    // modules/NotificationStack.qml's animation tracking):
                    // it must NOT change just because a message got added,
                    // or a growing group would look "new" again every
                    // time. It still can't be groupKey, which two
                    // unrelated groups can share (e.g. Zen Browser,
                    // interrupted by Ghostty, posting again later makes a
                    // second Zen Browser group with the same groupKey) —
                    // those two need different ids despite the collision.
                    id: row.id,
                    groupKey: row.groupKey,
                    appName: row.appName,
                    appIcon: row.appIcon,
                    messages: [row],
                    expiresAt: row.receivedAtMs + root.autoHideMs
                })
            }
        }
        return groups
    }

    // notification.dismiss() throws if the notification already closed on
    // its own (server-side auto-expiry beats most users to the click) —
    // the underlying object is gone by then, so there's nothing left to
    // dismiss anyway. Swallowing it here is what actually matters: an
    // uncaught throw here used to abort the rest of the calling function
    // before it ever reached the `history` filter below, so a click on an
    // already-expired notification silently did nothing at all.
    function safeDismiss(notification) {
        try {
            notification.dismiss()
        } catch (e) {
            // already closed — nothing to do
        }
    }

    // Removal is id-based, not reference-based (`Set.has(entry)` on the
    // entry objects themselves) — QML's `property var` doesn't reliably
    // preserve JS object identity for a value built in one binding
    // (this file's `groups`) and read from another file/component
    // (modules/NotificationStack.qml's `displayGroups`, itself rebuilt via
    // Object.assign on every recompute). Two reads of "the same" entry
    // ended up as distinct object instances with identical field values —
    // confirmed live (matching summary and receivedAtMs, but
    // `history.indexOf(entry) === -1`) — so dismissal silently filtered
    // against nothing and never removed anything. A plain integer id
    // assigned once at arrival sidesteps the whole question. The whole
    // card is the click target (see NotificationStack.qml), so this is
    // the only removal path — no per-message dismiss anymore.
    function dismissGroup(messages) {
        for (const entry of messages)
            if (entry.notification)
                root.safeDismiss(entry.notification)
        const ids = new Set(messages.map(m => m.id))
        root.history = root.history.filter(row => !ids.has(row.id))
    }

    // Class/desktop-entry names never agree across the two sides: Hyprland
    // reports "app.zen_browser.zen" while the notification carries
    // "Zen Browser". Stripping everything but letters and digits makes
    // those "appzenbrowserzen" and "zenbrowser", which a containment test
    // then matches — punctuation-insensitive without needing a per-app
    // table. The >= 3 guard keeps a stub of a name from matching half the
    // desktop.
    function normalizeId(s) {
        return (s || "").toLowerCase().replace(/[^a-z0-9]/g, "")
    }

    // The dispatch string is NOT the usual "focuswindow address:0x...".
    // This Hyprland runs the Lua config parser, which routes the IPC
    // `dispatch` command through Lua, so the flat form comes back as
    // "')' expected near 'address'" and does nothing at all — and since
    // the error only reaches the socket reply nobody reads, it fails
    // completely silently. Quickshell's Toplevel.activate()
    // (wlr-foreign-toplevel) looks like the parser-proof way out and
    // isn't: measured here, Hyprland ignores it under the default
    // misc:focus_on_activate = false — the request lands on the right
    // toplevel and focus simply doesn't move. Same call, same reason, in
    // modules/pad/Search.qml. Addresses come back from Quickshell bare;
    // Hyprland's selectors want the 0x.
    function focusApp(entry) {
        if (!entry)
            return
        const wanted = [entry.groupKey, entry.appName]
            .map(root.normalizeId)
            .filter(s => s.length >= 3)
        if (wanted.length === 0)
            return
        const match = Hyprland.toplevels.values.find(t => {
            const cls = root.normalizeId(t.lastIpcObject && t.lastIpcObject.class)
            return cls.length >= 3 && wanted.some(w => cls.includes(w) || w.includes(cls))
        })
        if (match)
            Hyprland.dispatch('hl.dsp.focus({ window = "address:0x' + match.address + '" })')
    }

    // Clicking a card means "take me to whatever posted this", not just
    // "make it go away". Two steps, because neither one alone is enough:
    //
    // - The freedesktop "default" action is the only thing that can land
    //   on the right *context* rather than just the right app — the actual
    //   Zen tab the web notification came from, the right chat thread. Apps
    //   that don't offer one simply don't have that ability, so it's
    //   best-effort; the try/catch is the same already-closed-notification
    //   guard safeDismiss() needs (the object is gone once the server
    //   expired it, and reading .actions off it throws).
    // - Raising the window is still done afterwards regardless: under
    //   Wayland an app can't reliably focus itself without an activation
    //   token and most don't try, so invoking the default action commonly
    //   switches the tab without ever bringing the window forward.
    //
    // Only the newest message in the group carries the action worth
    // following — that's the one that just fired and the one the click was
    // aimed at (groups are built newest-first, see `groups` above).
    function activateGroup(messages) {
        const newest = messages[0]
        if (newest && newest.notification) {
            try {
                for (const action of newest.notification.actions) {
                    if (action.identifier === "default") {
                        action.invoke()
                        break
                    }
                }
            } catch (e) {
                // already closed — no actions left to invoke
            }
        }
        root.focusApp(newest)
        root.dismissGroup(messages)
    }

    function dismissAll() {
        for (const row of root.history)
            if (row.notification)
                root.safeDismiss(row.notification)
        root.history = []
    }

    // notification.appIcon is often empty, or a name that doesn't match an
    // installed icon theme entry exactly. Quickshell.iconPath() passes an
    // unresolved name straight through rather than returning "" — so a
    // made-up guess like "zen-browser" comes back looking valid even when
    // it isn't, and Image fails to load it later. hasThemeIcon() is the
    // only reliable existence check, so guesses go through it first;
    // appIcon itself is trusted directly when it's already a path/URL
    // (the common case for apps that ship one) rather than a theme name.
    function resolveIcon(notification) {
        const raw = notification.appIcon
        if (raw && (raw.startsWith("/") || raw.includes("://") || Quickshell.hasThemeIcon(raw)))
            return Quickshell.iconPath(raw)

        const name = notification.appName || ""
        const guesses = [
            notification.desktopEntry,
            name,
            name.toLowerCase(),
            name.toLowerCase().replace(/\s+/g, "-"),
            name.toLowerCase().replace(/\s+/g, "")
        ]
        for (const guess of guesses) {
            if (guess && Quickshell.hasThemeIcon(guess))
                return Quickshell.iconPath(guess)
        }
        return ""
    }

    property NotificationServer server: NotificationServer {
        keepOnReload: false
        actionsSupported: true
        imageSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        persistenceSupported: true

        onNotification: notification => {
            notification.tracked = true

            const entry = {
                id: root.nextId++,
                notification: notification,
                appName: notification.appName,
                groupKey: notification.desktopEntry || notification.appName,
                appIcon: root.resolveIcon(notification),
                summary: notification.summary,
                body: notification.body,
                time: Qt.formatDateTime(new Date(), "hh:mm"),
                receivedAtMs: Date.now()
            }

            // Deliberately NOT wired to notification.closed: the server
            // fires that on its own internal timeout too (reason
            // "Expired"), not just when an app explicitly replaces/closes
            // its own notification — and per the "stays in history unless
            // you dismiss it yourself" requirement, auto-expiry must only
            // affect the corner's display (NotificationStack.qml's
            // expiresAt-based view filter), never the underlying data.
            root.history = [entry, ...root.history].slice(0, root.historyLimit)
        }
    }
}
