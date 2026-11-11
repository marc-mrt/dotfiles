pragma Singleton
import QtQuick
import Quickshell

// Session actions (lock, suspend, log out, reboot, power off) in one place
// so the power tab and, later, Search run identical commands. execDetached
// so a command outlives the shell: logout and poweroff kill us mid-flight.
// Confirmation is the caller's business — this only does.
QtObject {
    function lock() { Quickshell.execDetached(["hyprlock"]) }
    function suspend() { Quickshell.execDetached(["systemctl", "suspend"]) }
    function logout() { Quickshell.execDetached(["hyprctl", "dispatch", "exit"]) }
    function reboot() { Quickshell.execDetached(["systemctl", "reboot"]) }
    function poweroff() { Quickshell.execDetached(["systemctl", "poweroff"]) }
}
