//! End-aligned sidebar shortcuts that fade according to actual space, not a timer.
//! An optional expanding first child is a session name or a spacer for the window controls.
const gtk = @import("gtk");
const gobject = @import("gobject");
const std = @import("std");

pub fn new() *gtk.Box {
    const box = gtk.Box.new(.horizontal, 0);
    const w = box.as(gtk.Widget);
    w.setLayoutManager(gtk.CustomLayout.new(null, &measure, &allocate).as(gtk.LayoutManager));
    w.setHexpand(1);
    w.setOverflow(.hidden);
    return box;
}

fn measure(w: *gtk.Widget, orientation: gtk.Orientation, _: c_int, min: *c_int, nat: *c_int, mb: *c_int, nb: *c_int) callconv(.c) void {
    min.* = 0;
    nat.* = 0;
    mb.* = -1;
    nb.* = -1;
    // Optional buttons never set a minimum sidebar width, even mid-drag.
    if (orientation == .horizontal) return;
    var child = w.getFirstChild();
    while (child) |c| : (child = c.getNextSibling()) {
        var cm: c_int = 0;
        var cn: c_int = 0;
        c.measure(.vertical, -1, &cm, &cn, null, null);
        min.* = @max(min.*, cm);
        nat.* = @max(nat.*, cn);
    }
}

fn allocate(w: *gtk.Widget, width: c_int, height: c_int, _: c_int) callconv(.c) void {
    const first = w.getFirstChild() orelse return;
    const lead = first.getHexpand() != 0 and first.getVisible() != 0;
    var reserve: c_int = 0;
    if (lead) {
        first.measure(.horizontal, -1, null, &reserve, null, null);
        if (gobject.ext.cast(gtk.Label, first) != null) reserve = @min(@divTrunc(width * 2, 3), @max(64, reserve));
    }
    const rtl = w.getDirection() == .rtl;
    var end = width;
    var child = w.getLastChild();
    while (child) |c| : (child = c.getPrevSibling()) {
        if (lead and c == first) break;
        if (c.getVisible() == 0) continue;
        var cw: c_int = 0;
        c.measure(.horizontal, -1, null, &cw, null, null);
        const x = end - cw;
        const alpha = opacity(x - reserve);
        c.setChildVisible(@intFromBool(alpha > 0));
        if (alpha > 0) {
            c.setOpacity(alpha);
            c.sizeAllocate(&.{ .f_x = if (rtl) width - end else x, .f_y = 0, .f_width = cw, .f_height = height }, -1);
        }
        end = x - 2;
    }
    if (lead) {
        const lw = std.math.clamp(@max(end, reserve), 0, width);
        first.sizeAllocate(&.{ .f_x = if (rtl) width - lw else 0, .f_y = 0, .f_width = lw, .f_height = height }, -1);
    }
}

fn opacity(clearance: c_int) f64 {
    return std.math.clamp(@as(f64, @floatFromInt(clearance)) / 16, 0, 1);
}

test "shortcut fades over the last 16 pixels and is gone before it overlaps" {
    try std.testing.expectEqual(0.0, opacity(-1));
    try std.testing.expectEqual(0.0, opacity(0));
    try std.testing.expectEqual(0.5, opacity(8));
    try std.testing.expectEqual(1.0, opacity(20));
}
