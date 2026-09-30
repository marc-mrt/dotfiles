pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland

// Everything that knows how this particular Hyprland has to be talked to.
// Three files were building the focus dispatch by hand and two were
// resolving window icons by hand, with the 0x address prefix handled
// differently at each site — SwitcherState's addresses already carried it,
// Search and Notifications concatenated it, WindowSwitcher had a helper
// stripping it back off. Four sites, three conventions, and a failure mode
// that is completely silent.
//
// ── why the dispatch string looks like that ─────────────────────────────
// It is NOT the usual "focuswindow address:0x...". This Hyprland runs the
// Lua config parser, which routes the IPC `dispatch` command through Lua,
// so the flat form comes back as "')' expected near 'address'" and does
// nothing at all — and since that error only reaches the socket reply
// nobody reads, it fails completely silently. Quickshell's
// Toplevel.activate() (wlr-foreign-toplevel) looks like the parser-proof
// way out and isn't: measured here, Hyprland ignores it under the default
// misc:focus_on_activate = false — the request lands on the right toplevel
// and focus simply doesn't move. This paragraph used to be written out
// twice, in two files, in near-identical wording.
QtObject {
    id: root

    // hyprctl's addresses carry a 0x prefix; Quickshell.Hyprland's
    // HyprlandToplevel.address comes back bare. Both forms are accepted
    // everywhere here, so no caller has to remember which one it holds.
    function bareAddress(address) {
        const a = String(address || "")
        return a.startsWith("0x") ? a.slice(2) : a
    }

    // Move real keyboard focus to a window. Hyprland's selectors want the
    // 0x back on, whichever form came in.
    function focusWindow(address) {
        const bare = root.bareAddress(address)
        if (bare.length === 0)
            return
        Hyprland.dispatch('hl.dsp.focus({ window = "address:0x' + bare + '" })')
    }

    // Window class -> desktop entry -> theme icon path. "" when the class
    // is empty or nothing in the theme matches, which every caller renders
    // as a fallback glyph rather than a blank.
    function iconForClass(cls) {
        if (!cls)
            return ""
        const entry = DesktopEntries.heuristicLookup(cls)
        return entry ? Quickshell.iconPath(entry.icon, "") : ""
    }

    // The live toplevel's wayland handle — what ScreencopyView captures
    // from. Raw `hyprctl clients -j` JSON has no handle in it, so the
    // switcher has to come back through Quickshell's own toplevel list to
    // find one.
    function waylandHandle(address) {
        const bare = root.bareAddress(address)
        const t = Hyprland.toplevels.values.find(x => x.address === bare)
        return t ? t.wayland : null
    }
}
