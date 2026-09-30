import QtQuick
import "../../config"

// Every translucent bordered surface in the shell. Two variants, because
// the shell only ever has two: raised — a surface floating above content
// (the pad, a notification, the OSD toast, the switcher board, a tooltip,
// a tray menu) — and sunken, a group of controls inset *into* one of those
// (every tab section, the overview's expansion slot).
//
// These were written out longhand at eight call sites, and the fill alpha
// had drifted to four values (.90 / .92 / .95 / .97) with the border alpha
// drifting separately (.08 / .10 / .14). None of that was deliberate: the
// comments around them explain carefully what an accent border *means*,
// but nothing ever said why a tooltip should be more opaque than a
// notification. One number per role, private to this file, so a new
// surface matches the rest for free.
//
// `accented` is the one variation that does carry meaning — an accent
// border says "this surface holds the compositor's focus", which is the
// pad's alone (see modules/Pad.qml). Naming it keeps that cue explicit
// instead of an unexplained exception at one call site. Callers that need
// a different corner radius (the pad and the switcher board are both 20)
// just set `radius`; everything else takes the default for its variant.
Rectangle {
    id: root

    property bool sunken: false
    property bool accented: false

    radius: root.sunken ? 12 : 14
    color: root.sunken
        ? Colors.alpha(Colors.base, 0.45)
        : Colors.alpha(Colors.surface, 0.92)
    border.width: 1
    border.color: root.accented
        ? Colors.accent
        : Colors.alpha(Colors.text, root.sunken ? 0.06 : 0.10)
}
