-- Wayland-native Electron (Discord, VSCode, etc.)
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

-- Clutter
hl.env("CLUTTER_BACKEND", "wayland")

-- SDL games/apps
hl.env("SDL_VIDEODRIVER", "wayland")

-- GTK
hl.env("GDK_BACKEND", "wayland,x11")  -- graceful fallback

-- Qt
hl.env("QT_QPA_PLATFORM", "wayland")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")

-- Steam
hl.env("STEAM_FORCE_DESKTOPUI_SCALING", "1.5")

-- Hyprcursor
hl.env("HYPRCURSOR_THEME", "Catppuccin Latte Light")
hl.env("HYPRCURSOR_SIZE", "24")

