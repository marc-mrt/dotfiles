//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import "./modules"
import "./services"
import "./config"

ShellRoot {
    // SUPER+SPACE / SUPER+Tab (see hypr/lua/key_bindings.lua) run these via
    // `qs ipc call pad ...` without needing a dedicated global-shortcut
    // protocol. toggleOverview opens straight to the meta-info overview
    // (was SUPER+W / SUPER+SPACE-drun); toggleWindows opens straight to
    // unified search pre-biased toward open windows (was SUPER+Tab/rofi).
    IpcHandler {
        target: "pad"
        function toggleOverview(): void {
            PadState.toggle("")
        }
        function toggleWindows(): void {
            PadState.toggle("windows")
        }
    }

    // Pad — single floating card, no multi-monitor handling (deliberate,
    // this shell only ever targets one screen). Overlay layer, floats
    // above fullscreen windows and (via OnDemand keyboard focus, see
    // below) is immediately typable the instant SUPER+SPACE/SUPER+Tab
    // opens it, even over a focused fullscreen app.
    //
    // Deliberately NOT full-width: a full-screen surface here would sit on
    // top of notifWin below at that corner (each time the pad opens it
    // remaps, landing above the already-mapped notification stack) and
    // swallow clicks meant for it. `PanelWindow.mask` is documented for
    // exactly this (carve a hole, let clicks fall through to whatever's
    // behind) but had no effect at all when tried here — so this reserves
    // real screen space instead (Metrics.notifReserveWidth/Height): this
    // window stops short of the right margin reserved for notifications,
    // and padCornerCatcher below covers the top-right the rest of the
    // way, leaving an actual non-overlapping gap at the bottom-right for
    // notifWin. Height stays full screen — shrinking height instead of
    // width clips the card whenever it grows tall (many search results);
    // the card sits near the top and can extend well past a shortened
    // window, but is horizontally centered nowhere near the reserved
    // right column, so trimming width instead doesn't affect it.
    //
    // Both padWin and padCornerCatcher below are gated purely on
    // PadState.shown — unlike a merged pad+notifications window (tried
    // and reverted once: a full-screen surface mapped whenever a
    // notification existed, not just when the pad was open, silently ate
    // every click on the rest of the desktop), neither of these can ever
    // be mapped, let alone full-screen, while the pad is closed.
    PanelWindow {
        id: padWin
        screen: Quickshell.screens[0]
        visible: PadState.shown

        anchors {
            top: true
            bottom: true
            left: true
        }
        implicitWidth: screen.width - Metrics.notifReserveWidth
        exclusiveZone: 0
        color: "transparent"

        WlrLayershell.layer: WlrLayer.Overlay
        // OnDemand, not Exclusive: a layer surface holding Exclusive
        // keyboard focus captures ALL pointer input globally in Hyprland,
        // regardless of its actual input region/geometry — a confirmed
        // Hyprland bug (github.com/hyprwm/Hyprland/discussions/14136),
        // not something fixable from this side. That's what was silently
        // eating clicks meant for notifWin's separate, non-overlapping
        // surface even though the padWin/padCornerCatcher geometry split
        // above was already correct. Confirmed OnDemand still focuses for
        // typing the instant SUPER+SPACE opens the pad — no regression.
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        Pad {
            anchors.fill: parent
        }
    }

    // Top-right leg of the same "click outside closes the pad" catcher —
    // see padWin above. Together they cover the whole screen except the
    // bottom-right corner reserved for notifWin.
    PanelWindow {
        id: padCornerCatcher
        screen: Quickshell.screens[0]
        visible: PadState.shown

        anchors {
            top: true
            right: true
        }
        implicitWidth: Metrics.notifReserveWidth
        implicitHeight: screen.height - Metrics.notifReserveHeight
        exclusiveZone: 0
        focusable: false
        color: "transparent"

        WlrLayershell.layer: WlrLayer.Overlay

        MouseArea {
            anchors.fill: parent
            onClicked: PadState.close()
        }
    }

    // Notification stack — independent of the pad, same split as the OSD
    // below: fires regardless of whether the pad is open, so a notification
    // during a fullscreen video is still seen. Overlay layer for the same
    // reason; unfocusable so it never steals keyboard input. Bottom-right
    // corner, sized to content (not full-width), which matters even more
    // now: an oversized surface here would block clicks to the desktop
    // underneath across its whole bounds, not just where content actually
    // renders (see padWin's comment above for how that bit us).
    PanelWindow {
        id: notifWin
        screen: Quickshell.screens[0]
        visible: Notifications.groups.length > 0

        anchors {
            bottom: true
            right: true
        }
        margins.bottom: 12
        margins.right: 12
        implicitWidth: notifContent.implicitWidth
        implicitHeight: notifContent.implicitHeight
        exclusiveZone: 0
        focusable: false
        color: "transparent"

        WlrLayershell.layer: WlrLayer.Overlay

        NotificationStack {
            id: notifContent
        }
    }

    // Hyprland-side focus for the pad. WlrKeyboardFocus only tells the
    // compositor that this layer accepts keys — Hyprland still counts the
    // last real window as the focused one, so opening the pad left the
    // window underneath fully active (its border, its idea of "the current
    // window") while the pad typed over it. hyprland_focus_grab_v1 is the
    // protocol built for exactly this: while the grab holds, Hyprland
    // treats the grabbed surfaces as what's focused, and the window
    // underneath drops to its inactive treatment.
    //
    // notifWin joins the grab, but only while it's actually mapped — NOT
    // to focus it (it stays focusable: false, never takes keyboard focus,
    // and no longer wears the focused-card border either, see
    // modules/NotificationStack.qml) but so a click on a notification
    // reaches the card instead of being eaten as "clicked outside the
    // grab". That's the same failure mode Exclusive keyboard focus caused
    // above; naming the surface here is the supported way out of it.
    //
    // Deliberately no onCleared -> PadState.close(): padWin and
    // padCornerCatcher already cover every pixel that isn't notifWin and
    // close the pad themselves, and the `windows` list below re-commits
    // whenever the notification stack empties or fills — a cleared handler
    // would read that ordinary re-grab as "user clicked away" and close
    // the pad the moment a notification arrived.
    HyprlandFocusGrab {
        active: PadState.shown
        windows: Notifications.groups.length > 0
            ? [padWin, padCornerCatcher, notifWin]
            : [padWin, padCornerCatcher]
    }

    // OSD — transient toast for volume/brightness changes made outside
    // Quickshell (hardware keys, hypridle, other apps). Non-exclusive,
    // unfocusable, and collapses to 0 height while hidden so it never
    // reserves screen space or steals input.
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: osdWin
            required property var modelData
            screen: modelData

            anchors {
                bottom: true
                left: true
                right: true
            }
            margins.bottom: 64
            implicitHeight: Osd.visible ? osdCard.implicitHeight : 0
            exclusiveZone: 0
            focusable: false
            color: "transparent"

            Rectangle {
                id: osdCard
                visible: Osd.visible
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                implicitWidth: osdContent.implicitWidth + 32
                implicitHeight: osdContent.implicitHeight + 20
                radius: 14
                color: Colors.alpha(Colors.surface, 0.9)
                border.width: 1
                border.color: Colors.alpha(Colors.text, 0.08)

                OsdToast {
                    id: osdContent
                    anchors.centerIn: parent
                }
            }
        }
    }
}
