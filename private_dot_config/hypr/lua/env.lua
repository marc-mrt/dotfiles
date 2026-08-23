-- Wayland-native Electron (Discord, VSCode, etc.)
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

-- Clutter
hl.env("CLUTTER_BACKEND", "wayland")

-- SDL games/apps
hl.env("SDL_VIDEODRIVER", "wayland")

-- GTK
hl.env("GDK_BACKEND", "wayland,x11")  -- graceful fallback
hl.env("GDK_SCALE", "1.25")

-- Qt
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1.25")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")

-- Steam
hl.env("STEAM_FORCE_DESKTOPUI_SCALING", "1.25")

-- Hyprcursor
hl.env("HYPRCURSOR_THEME", "Catppuccin Latte Light")
hl.env("HYPRCURSOR_SIZE", "24")

-- Fallback for XCURSOR
hl.env("XCURSOR_THEME", "catppuccin-latte-light-cursors")
hl.env("XCURSOR_SIZE", "24")
hl.env("XCURSOR_PATH", "/home/marc/.local/share/icons:/usr/share/icons")

-- XDG
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
