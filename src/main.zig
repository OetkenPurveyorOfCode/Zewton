const std = @import("std");
const bmp = @cImport({
    @cInclude("bmp.h");
});
const c = std.math.complex;
const ziglogo = @embedFile("ziglogo.bin");
const ziglogo_light = @embedFile("ziglogo_light.bin");
const ziglogo_dark = @embedFile("ziglogo_dark.bin");
const ziglogo_width = 312;
const ziglogo_height = 312;
const MAX_ITER = 1000;

fn f(z: c.Complex(f64)) c.Complex(f64) {
    return c.pow(c.Complex(f64), z, c.Complex(f64).init(3, 0)).sub(c.Complex(f64).init(1, 0));
}

fn df_dz(z: c.Complex(f64)) c.Complex(f64) {
    const three = c.Complex(f64).init(3, 0);
    return three.mul(z.mul(z));
}

fn tofloat(x: usize) f64 {
    return @as(f64, @floatFromInt(x));
}

fn newton(z_arg: c.Complex(f64)) u32 {
    var z = z_arg;
    for (0..MAX_ITER-1) |iter| {
        z = z.sub(f(z).div(df_dz(z)));
        const eps: f64 = 1e-6;
        for (roots, 0..) |root, i| {
            const diff = root.sub(z);
            if (diff.magnitude() < eps) {
                return get_color(z_arg.mul(c.Complex(f64).init(@as(f64, @floatFromInt(iter)), 0)), i);
            }
        }
    }
    return 0;
}

fn get_color_mindist(mindist:f64) u32 {
    return @intFromFloat(clamp(mindist*255.0, 0.0, 255.0));
}

fn clamp(x: f64, min: f64, max: f64) f64 {
    if (x <= min) {
        return min;
    }
    else if (x > max) {
        return max;
    }
    else {
        return x;
    }
}

fn texture(real: f64, imag: f64, i: usize) u32 {
    const x = real*ziglogo_width;
    const y = imag*ziglogo_height;
    const index : usize = (@as(usize, @intFromFloat(x)) + @as(usize, @intFromFloat(y))*ziglogo_width) * 4;
    var logo = ziglogo;
    if (i == 1) {
        logo = ziglogo_light;
    }
    if (i == 2) {
        logo = ziglogo_dark;
    }
    var result: u32 = @as(u32, logo[index]) << 16 | @as(u32, logo[index+1]) << 8 | @as(u32, logo[index+2]);
    return result;
}

fn get_color(z: c.Complex(f64), i: usize) u32 {
	var real = 3*z.re;
    var imag = 3*z.im;
    real = @mod(real, 1.0);
    imag = @mod(imag, 1.0);
	return texture(real, imag, i);
}

const roots = [_]c.Complex(f64){
    c.Complex(f64).init(1.0, 0.0),
    c.Complex(f64).init(-0.5, 0.5 * std.math.sqrt(3.0)),
    c.Complex(f64).init(-0.5, -0.5 * std.math.sqrt(3.0)),
};

const colors = [_]u32{
    0xFF_00_00,
    0x00_FF_00,
    0x00_00_FF,
};

pub fn main() !void {
    const width: u32 = 1920;
    const height: u32 = 1080;
    const size = bmp.bmp_size(width, height);
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var buffer = try std.ArrayList(u8).initCapacity(gpa.allocator(), size);
    try buffer.resize(size);
    bmp.bmp_init(buffer.items.ptr, width, height);

    const zxmin = -2.5;
    const zxmax = 1;
    var zx: f64 = zxmin;
    const zymin = -2;
    const zymax = 2;
    var zy: f64 = zymin;
    const dzx: f64 = (zxmax - zxmin) / @as(f64, @floatFromInt(width));
    const dzy = (zymax - zymin) / @as(f64, @floatFromInt(height));

    for (0..height - 1) |row| {
        for (0..width - 1) |col| {
            const z = c.Complex(f64).init(zx, zy);
            bmp.bmp_set(buffer.items.ptr, @as(u31, @truncate(col)) * @as(c_long, 1), @as(u31, @truncate(row)) * @as(c_long, 1), newton(z));
            zx += dzx;
        }
        zx = zxmin;
        zy += dzy; // accumulates errors, but is faster: Should I do zx = (zxmax - zxmin) / @as(f64, @floatFromInt(width)) * @as(f64, @floatFromInt(col)) instead?
    }
    var fd = try std.fs.cwd().createFile("newton.bmp", .{});
    _ = try fd.write(buffer.items);
    fd.close();
}
