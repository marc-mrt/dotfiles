#!/usr/bin/env lua
-- Renders theme templates from palette.lua. Pure renderer, no side effects —
-- live-apply (gsettings, hyprctl, nvim RPC, etc.) lives in apply-theme.sh.

local HOME = os.getenv("HOME")
local BASE = HOME .. "/.config/hypr/theme"
local palette = dofile(BASE .. "/palette.lua")

local targets = {
  { tpl = "gtk.css.tpl",          out = HOME.."/.config/gtk-3.0/gtk.css" },
  { tpl = "gtk.css.tpl",          out = HOME.."/.config/gtk-4.0/gtk.css" },
  { tpl = "gtk-settings.ini.tpl", out = HOME.."/.config/gtk-3.0/settings.ini" },
  { tpl = "gtk-settings.ini.tpl", out = HOME.."/.config/gtk-4.0/settings.ini" },
  { tpl = "xresources.tpl",       out = HOME.."/.Xresources" },
  { tpl = "hypr-colors.lua.tpl",  out = HOME.."/.config/hypr/colors.lua" },
  { tpl = "ghostty-colors.tpl",   out = HOME.."/.config/ghostty/colors" },
  { tpl = "nvim-palette.lua.tpl", out = HOME.."/.config/nvim/lua/palette.lua" },
  { tpl = "hyprlock-colors.tpl",  out = HOME.."/.config/hypr/hyprlock-colors.conf" },
  { tpl = "colors.json.tpl",      out = HOME.."/.config/quickshell/generated/colors.json" },
}

local function read_file(path)
  local f = assert(io.open(path, "r"))
  local c = f:read("*a"); f:close(); return c
end

local function write_file(path, content)
  os.execute(string.format('mkdir -p "%s"', path:match("(.*/)")))
  local f = assert(io.open(path, "w"))
  f:write(content); f:close()
end

-- Auto-derive a "<key>_stripped" (no '#') variant for every #RRGGBB value,
-- so templates can use {{accent_stripped}} without palette.lua duplicating
-- every color in both forms.
local function extend_vars(vars)
  local ext = {}
  for k, v in pairs(vars) do
    ext[k] = v
    if type(v) == "string" and v:match("^#%x%x%x%x%x%x$") then
      ext[k .. "_stripped"] = v:sub(2)
    end
  end
  return ext
end

local function render(tpl, vars)
  return (tpl:gsub("{{([%w_]+)}}", function(key)
    local v = vars[key]
    if v == nil then
      io.stderr:write("warning: missing palette key '" .. key .. "'\n")
      return "{{" .. key .. "}}"
    end
    return tostring(v)
  end))
end

local vars = extend_vars(palette)

for _, t in ipairs(targets) do
  local rendered = render(read_file(BASE .. "/templates/" .. t.tpl), vars)
  write_file(t.out, rendered)
end

-- Flat shell-sourceable env file — the bridge from Lua to bash.
local function envq(v)
  return '"' .. tostring(v):gsub('"', '\\"') .. '"'
end

local env_lines = {
  "GTK_THEME="    .. envq(palette.gtk_theme_name),
  "GTK_SCHEME="   .. envq(palette.gtk_scheme),
  "CURSOR_THEME=" .. envq(palette.cursor_theme),
  "CURSOR_SIZE="  .. envq(palette.cursor_size),
  "NVIM_SCHEME="  .. envq(palette.nvim_scheme),
  "NVIM_BG="      .. envq(palette.nvim_background),
}
write_file(BASE .. "/palette.env", table.concat(env_lines, "\n") .. "\n")

print("theme render: " .. palette.name .. " -> templates + palette.env")
