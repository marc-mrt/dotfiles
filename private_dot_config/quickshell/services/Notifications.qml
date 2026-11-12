pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
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
// (pad/chips/Notifications.qml) — it doesn't hide anything, same as
// dunst's pause mode never hid history either.
QtObject {
    id: root

    readonly property int historyLimit: 20

    property var history: []
    property bool dnd: false
    property int nextId: 0

    // history/dnd/nextId survive a hot reload (any config edit) by being
    // written to a file in $XDG_RUNTIME_DIR and read back on construction.
    // PersistentProperties was tried and doesn't work here: it can't carry
    // a JS array between reloads ("JSValue can't be reassigned to another
    // engine"), and it doesn't restore at all for a property declared on a
    // singleton. The runtime dir (tmpfs) rather than ~/.local/state so it
    // is wiped on logout/reboot — after a real restart the notification
    // objects are gone and the rows would just be dead history.
    // history is plain data only, never the Notification objects: those
    // live in `live` below, rebuilt after a reload (see onNotification).
    property FileView stateFile: FileView {
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/quickshell-notifications.json"
        blockLoading: true
        atomicWrites: true
        // Missing file is the normal first run.
        onLoadFailed: {}
    }
    property bool restored: false
    Component.onCompleted: {
        try {
            const v = JSON.parse(root.stateFile.text())
            root.history = v.history
            root.dnd = v.dnd
            root.nextId = v.nextId
        } catch (e) {
            // missing or corrupt: start empty
        }
        root.restored = true
    }
    // Gated on `restored` so the initial empty values never overwrite the
    // file before it has been read.
    function save() {
        if (root.restored)
            root.stateFile.setText(JSON.stringify({
                history: root.history, dnd: root.dnd, nextId: root.nextId
            }))
    }
    onHistoryChanged: root.save()
    onDndChanged: root.save()

    // entry id -> its Notification, for as long as the server still has it.
    // An entry with no live notification (closed, or from before a reload
    // that didn't re-deliver it) is still a perfectly good history row —
    // it just has no action buttons and a click only removes it. Not
    // reactive; anything that has to re-render when this changes reassigns
    // `history` (see attach()).
    property var live: ({})

    function attach(entry, notification) {
        root.live[entry.id] = notification
        // Dropping the reference when the server closes it is what makes
        // actionsOf() stop offering buttons that can't work. This is NOT
        // the "removed from history" hook the onNotification comment
        // rules out — history is left alone, only the buttons go.
        notification.closed.connect(() => {
            delete root.live[entry.id]
            root.history = root.history.slice()
        })
    }

    // Keyboard-driven selection while the pad is open (Tab/Shift+Tab to
    // move, Enter to activate, Backspace/Delete to dismiss — see
    // modules/Pad.qml's keyCatcher). Tracked by group id, not index: ids
    // stay fixed as `groups` is rebuilt (see below), so a card growing or
    // a sibling being dismissed doesn't shift the selection onto the wrong
    // card the way an index would. -1 means nothing selected. Self-healing
    // if the selected group vanishes from under it (dismissed some other
    // way) — selectedGroup() below just finds nothing and callers no-op.
    property int selectedGroupId: -1

    function clearSelection() {
        root.selectedGroupId = -1
    }

    function selectedGroup() {
        return root.groups.find(g => g.id === root.selectedGroupId) || null
    }

    function selectNext() {
        if (root.groups.length === 0) {
            root.selectedGroupId = -1
            return
        }
        const idx = root.groups.findIndex(g => g.id === root.selectedGroupId)
        root.selectedGroupId = root.groups[(idx + 1) % root.groups.length].id
    }

    function selectPrev() {
        if (root.groups.length === 0) {
            root.selectedGroupId = -1
            return
        }
        const idx = root.groups.findIndex(g => g.id === root.selectedGroupId)
        root.selectedGroupId = root.groups[idx <= 0 ? root.groups.length - 1 : idx - 1].id
    }

    function activateSelected() {
        const g = root.selectedGroup()
        if (g) {
            root.activateGroup(g.messages)
            root.selectedGroupId = -1
        }
    }

    function dismissSelected() {
        const g = root.selectedGroup()
        if (g) {
            root.dismissGroup(g.messages)
            root.selectedGroupId = -1
        }
    }

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
            if (root.live[entry.id])
                root.safeDismiss(root.live[entry.id])
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

    // Focus quirks (the Lua-parser dispatch form, the 0x prefix) live in
    // services/Hypr.qml — this only has to work out *which* window.
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
            Hypr.focusWindow(match.address)
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
        if (newest && root.live[newest.id]) {
            try {
                for (const action of root.live[newest.id].actions) {
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

    // Card buttons for a message's non-default actions. "default" is
    // excluded because clicking the card already invokes it
    // (activateGroup). Shaped as the plain object modules/ui/MenuEntry
    // reads (text/enabled/icon/...) so the card can reuse that primitive
    // instead of growing its own button. Returns [] unless the live
    // notification object still exists: reading .actions off one the
    // server already closed throws (same guard as safeDismiss), and an
    // action on a dead notification can't be invoked anyway.
    function actionsOf(entry) {
        const out = []
        const notification = root.live[entry.id]
        if (!notification)
            return out
        try {
            for (const action of notification.actions) {
                if (action.identifier === "default")
                    continue
                out.push({
                    text: action.text,
                    enabled: true,
                    icon: "",
                    isSeparator: false,
                    hasChildren: false,
                    triggered: () => root.invokeAction(entry, action.identifier)
                })
            }
        } catch (e) {
            // already closed — no buttons
        }
        return out
    }

    // Invoke by identifier, looked up again at click time rather than
    // holding the NotificationAction from actionsOf: the notification may
    // have closed in between, in which case invoking is moot. Removes just
    // this message (not its whole group) — the button answered it, the
    // neighbours are still unread — via the same dismissGroup() a click uses.
    function invokeAction(entry, identifier) {
        try {
            for (const action of root.live[entry.id].actions) {
                if (action.identifier === identifier) {
                    action.invoke()
                    break
                }
            }
        } catch (e) {
            // already closed — nothing to invoke
        }
        root.dismissGroup([entry])
    }

    function dismissAll() {
        for (const row of root.history)
            if (root.live[row.id])
                root.safeDismiss(root.live[row.id])
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

    // The line thumbnail is for content (avatar, screenshot, album art) only.
    // Many apps send their own icon as `image`, which would show a second
    // identity icon next to the header's. Computed from the entry's stored
    // fields at read time, so entries persisted before this rule existed
    // follow it too.
    function contentImageOf(entry) {
        const img = entry.image || ""
        if (!img || img.startsWith("image://icon/") || img === entry.appIcon)
            return ""
        return img
    }

    property NotificationServer server: NotificationServer {
        // true (also the default) is what lets live notifications — and so
        // their action buttons — survive a reload. It was false because a
        // kept server re-emits every still-tracked notification through
        // onNotification afterwards, which used to mean duplicates of what
        // history already held; onNotification now recognises those
        // (lastGeneration) and re-attaches instead of re-adding.
        keepOnReload: true
        actionsSupported: true
        imageSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        persistenceSupported: true

        onNotification: notification => {
            notification.tracked = true

            // Re-delivery of one we already hold, after a reload: hand it
            // its entry back (by the server's own id — our entry ids
            // don't mean anything to it) rather than adding a duplicate.
            // One with no entry was already out of history (trimmed past
            // historyLimit) — nothing to show, so let it go.
            if (notification.lastGeneration) {
                const known = root.history.find(r => r.dbusId === notification.id)
                if (known) {
                    root.attach(known, notification)
                    root.history = root.history.slice()
                } else {
                    root.safeDismiss(notification)
                }
                return
            }

            const entry = {
                id: root.nextId++,
                dbusId: notification.id,
                appName: notification.appName,
                groupKey: notification.desktopEntry || notification.appName,
                appIcon: root.resolveIcon(notification),
                summary: notification.summary,
                body: notification.body,
                // Copied now, like the other fields: the entry has to
                // render after the notification object is gone. May be
                // empty (most notifications carry no image).
                image: notification.image,
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
            root.attach(entry, notification)
            root.history = [entry, ...root.history].slice(0, root.historyLimit)
        }
    }
}
