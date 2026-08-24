//@ pragma UseQApplication
import QtQuick
import Quickshell
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

    // Pad — a real XDG toplevel, NOT a layer surface, and screen-sized.
    // Both halves of that matter:
    //
    // Toplevel, because a layer surface can never be "the focused window"
    // to Hyprland. It focuses one on map and typing lands there, but it
    // deliberately keeps its last-window pointer aimed at whatever was
    // focused before, so it knows where to hand focus back when the layer
    // goes away — and every visual cue reads that pointer, not keyboard
    // focus. The window underneath kept its active border, stayed undimmed
    // under dim_inactive, stayed at full inactive_opacity, and
    // `hyprctl activewindow` kept naming it. None of that is configurable;
    // it's what a layer surface *is*. As a toplevel, Hyprland focuses this
    // on map like any other window and all of the above just happens.
    //
    // Screen-sized, because a floating toplevel cannot resize itself after
    // it maps — measured: Hyprland keeps the size it configured at map
    // time and ignores every later implicitWidth/implicitHeight change. A
    // card-sized window would therefore be frozen at whatever size it
    // opened with, killing the 576->768 search growth. Sizing the window
    // to the whole screen sidesteps that completely: the window never
    // changes size, only the card inside it does, which is plain QML
    // layout that Hyprland never sees.
    //
    // The full-screen input region also does what the old layer overlay
    // was widened to do: with input:follow_mouse = 1 (hypr/lua/options.lua)
    // any pixel this doesn't cover is one where drifting the mouse hands
    // focus to the window underneath, out from under the pad you're still
    // typing into. Nothing to carve out here — notifWin below is on the
    // overlay layer, which renders above windows, so it stays visible and
    // clickable over this without needing a hole.
    //
    // Positioning, float/pin and border suppression come from the
    // `quickshell-pad` rule in hypr/lua/window_rules.lua, matched on this
    // window's class (org.quickshell).
    FloatingWindow {
        id: padWin
        screen: Quickshell.screens[0]
        visible: PadState.shown
        title: "quickshell-pad"

        implicitWidth: padWin.screen.width
        implicitHeight: padWin.screen.height
        color: "transparent"

        Pad {
            anchors.fill: parent
        }
    }

    // Notification stack — independent of the pad, same split as the OSD
    // below: fires regardless of whether the pad is open, so a notification
    // during a fullscreen video is still seen. Overlay layer, which puts it
    // above ordinary windows and therefore above padWin too — that's what
    // lets it keep working unchanged while the pad covers the screen.
    // Unfocusable, so clicking a card can't take focus off the pad.
    // Bottom-right, sized to content (not full-width), so it blocks clicks
    // to the desktop underneath only where content actually renders.
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

    // No HyprlandFocusGrab here anymore: that protocol exists to give a
    // layer surface something focus-shaped, and padWin is a real window
    // now — Hyprland focuses it on map like anything else, with no help.

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
