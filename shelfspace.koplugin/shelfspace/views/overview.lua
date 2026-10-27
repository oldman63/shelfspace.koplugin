local CenterContainer = require("ui/widget/container/centercontainer")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local IconWidget = require("ui/widget/iconwidget")
local LineWidget = require("ui/widget/linewidget")
local OverlapGroup = require("ui/widget/overlapgroup")
local Size = require("ui/size")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local util = require("util")
local _ = require("gettext")
local N_ = _.ngettext
local T = require("ffi/util").template

local Donut = require("shelfspace/donut")
local Duplicates = require("shelfspace/duplicates")
local Stats = require("shelfspace/stats")
local UI = require("shelfspace/ui")
local sp = UI.sp

-- Free space, a usage bar and a books / KOReader / other breakdown.
return function(screen, th, width)
    local plugin = screen.plugin
    local u = plugin.usage
    local b = plugin.tree and plugin:breakdown(u) or nil

    local hero = UI.hero(th, width, {
        color = th.brand,
        icon = "shelfspace",
        named = true, -- the mark with the ShelfSpace wordmark under it
        title = _("Overview"),
        subtitle = T(_("%1 free of %2"), util.getFriendlySize(u.available), util.getFriendlySize(u.total)),
        chips = b and Stats.shareChips({
            { name = _("BOOKS"), bytes = b.books },
            { name = _("KOREADER"), bytes = b.koreader },
            { name = _("OTHER"), bytes = b.other },
            { name = _("FREE"), bytes = u.available },
        }, u.total, 3) or { _("SCANNING…") },
    })

    -- Rows with an on_tap show a chevron and open the matching tab; the others are plain.
    -- `note` is a muted line under the label; `on_info` adds an info icon that is the only
    -- thing on the row to tap. Every row ends in a slot of the same width so the sizes line up.
    local function legend(row_width, color, label, size_text, on_tap, note, on_info)
        local dot, gap = sp(14), sp(12)
        local slot = Geom:new{ w = sp(40), h = sp(30) }
        local tail
        if on_info then
            tail = UI.tappable(CenterContainer:new{
                dimen = slot,
                IconWidget:new{ icon = "notice-info", alpha = true, width = sp(24), height = sp(24) },
            }, on_info)
        else
            tail = CenterContainer:new{
                dimen = slot,
                on_tap and UI.text("›", 28, { color = th.muted }) or HorizontalSpan:new{ width = 1 },
            }
        end
        local label_w = UI.text(label, 22, { bold = true, color = th.ink })
        local size_w = UI.text(size_text, 22, { color = th.ink })
        local text_w = label_w
        if note then
            text_w = VerticalGroup:new{ align = "left", label_w, UI.text(note, 14, { color = th.muted }) }
        end
        local spacer = row_width - dot - gap - text_w:getSize().w - size_w:getSize().w - sp(8) - slot.w
        local row = VerticalGroup:new{
            align = "left",
            VerticalSpan:new{ width = sp(10) },
            HorizontalGroup:new{
                align = "center",
                FrameContainer:new{
                    bordersize = Size.border.thin, padding = 0, margin = 0, radius = dot, color = th.ink,
                    background = color,
                    HorizontalGroup:new{ HorizontalSpan:new{ width = dot }, VerticalSpan:new{ width = dot } },
                },
                HorizontalSpan:new{ width = gap }, text_w,
                HorizontalSpan:new{ width = math.max(spacer, 0) }, size_w,
                HorizontalSpan:new{ width = sp(8) },
                tail,
            },
            VerticalSpan:new{ width = sp(10) },
            LineWidget:new{ dimen = Geom:new{ w = row_width, h = Size.line.thin }, background = th.line },
        }
        return on_tap and UI.tappable(row, on_tap) or row
    end

    -- What each slice and legend row does when tapped; Free has nothing to open.
    local go = {
        books = function() screen:openBrowse(plugin.root) end,
        koreader = function() screen:switchTab("koreader") end,
        other = function() plugin:explainOther(b) end,
        duplicates = function() screen:openDuplicates() end,
    }
    local rows, slices
    if b then
        rows = {
            { th.books, _("Books"), util.getFriendlySize(b.books), go.books },
            { th.koreader, _("KOReader data"), util.getFriendlySize(b.koreader), go.koreader },
            { th.other, _("Other files"), util.getFriendlySize(b.other), nil, _("System files, locked"), go.other },
            { th.free_space, _("Free"), util.getFriendlySize(u.available) },
        }
        -- Only when there is something to decide about: a tidy library never sees this row. Sets you chose to
        -- keep stay reachable from here, so the way back to them is never lost.
        local sets, kept = plugin.duplicates or {}, #(plugin.ignored_duplicates or {})
        if #sets > 0 then
            local note = T(N_("%1 book more than once", "%1 books more than once", #sets), #sets)
            if kept > 0 then note = note .. T(_(" · %1 kept"), kept) end
            table.insert(rows, 3, { th.brand, _("Duplicates"), util.getFriendlySize(Duplicates.reclaimable(sets)), go.duplicates, note })
        elseif kept > 0 then
            table.insert(rows, 3, { th.brand, _("Duplicates"), "", go.duplicates, T(_("Nothing to clear · %1 kept on purpose"), kept) })
        end
        slices = {
            { fraction = b.books / u.total, color = th.books, on_tap = go.books },
            { fraction = b.koreader / u.total, color = th.koreader, on_tap = go.koreader },
            { fraction = b.other / u.total, color = th.other, on_tap = go.other },
            { fraction = u.available / u.total, color = th.free_space },
        }
    else
        rows = {
            { th.other, _("Used"), util.getFriendlySize(u.used) },
            { th.free_space, _("Free"), util.getFriendlySize(u.available) },
        }
        slices = {
            { fraction = u.used / u.total, color = th.other },
            { fraction = u.available / u.total, color = th.free_space },
        }
    end
    local landscape = screen.dimen.w > screen.dimen.h
    local gap = sp(12)
    local legend_width = landscape and math.floor(width * 0.61) or width
    local chart_width = landscape and (width - legend_width - gap) or width
    local legend_rows = VerticalGroup:new{ align = "left" }
    for i, r in ipairs(rows) do
        table.insert(legend_rows, legend(legend_width, r[1], r[2], r[3], r[4], r[5], r[6]))
    end

    -- As large as the screen leaves room for once the header, tabs and legend are placed.
    local room = screen.dimen.h - (sp(46) + sp(32) + hero:getSize().h + sp(62) + legend_rows:getSize().h + sp(24))
    local diameter
    if landscape then
        -- The legend sits beside the chart, so it no longer consumes vertical chart space.
        local chart_room = screen.dimen.h - (sp(46) + sp(32) + hero:getSize().h + sp(62) + sp(24))
        diameter = math.max(sp(80), math.min(chart_width - sp(8), sp(220), chart_room))
    else
        diameter = math.max(sp(110), math.min(math.floor(width * 0.62), sp(260), room))
    end
    local used_share = u.total > 0 and u.used / u.total or 0
    local donut = Donut:new{
        diameter = diameter, bg = th.bg, ink = th.ink, slices = slices,
        on_tap = function(slice) if slice.on_tap then slice.on_tap() end end,
    }
    local chart = CenterContainer:new{
        dimen = Geom:new{ w = chart_width, h = diameter + (landscape and 0 or sp(16)) },
        OverlapGroup:new{
            dimen = Geom:new{ w = diameter, h = diameter },
            donut,
            CenterContainer:new{
                dimen = Geom:new{ w = diameter, h = diameter },
                VerticalGroup:new{
                    align = "center",
                    UI.text(string.format("%d%%", 100 - math.floor(used_share * 100 + 0.5)), 34, { face = "tfont", color = th.ink }),
                    UI.text(_("free"), 16, { color = th.muted }),
                },
            },
        },
    }
    local body
    if landscape then
        body = HorizontalGroup:new{ align = "center", chart, HorizontalSpan:new{ width = gap }, legend_rows }
    else
        body = VerticalGroup:new{ align = "left", VerticalSpan:new{ width = sp(8) }, chart, legend_rows }
    end
    return { hero = hero, body = body }
end
