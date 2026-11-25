from PIL import Image, ImageDraw
import os


def quad(p0, p1, p2, steps=24):
    pts = []
    for i in range(1, steps + 1):
        t = i / steps
        x = (1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t**2 * p2[0]
        y = (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t**2 * p2[1]
        pts.append((x, y))
    return pts


def cubic(p0, p1, p2, p3, steps=28):
    pts = []
    for i in range(1, steps + 1):
        t = i / steps
        x = (
            (1 - t) ** 3 * p0[0]
            + 3 * (1 - t) ** 2 * t * p1[0]
            + 3 * (1 - t) * t**2 * p2[0]
            + t**3 * p3[0]
        )
        y = (
            (1 - t) ** 3 * p0[1]
            + 3 * (1 - t) ** 2 * t * p1[1]
            + 3 * (1 - t) * t**2 * p2[1]
            + t**3 * p3[1]
        )
        pts.append((x, y))
    return pts


def render_cat_icon(out_path, size, pad_ratio=0.10):
    ss = size * 4
    img = Image.new("RGBA", (ss, ss), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    pad = ss * pad_ratio
    span = ss - 2 * pad

    def pt(nx, ny):
        return (pad + nx * span, pad + ny * span)

    head_pts = [
        pt(0.20, 0.42),
        pt(0.16, 0.18),
        pt(0.40, 0.32),
    ]
    head_pts += quad(pt(0.40, 0.32), pt(0.50, 0.35), pt(0.60, 0.32))
    head_pts += [pt(0.84, 0.18), pt(0.80, 0.42)]
    head_pts += cubic(pt(0.80, 0.42), pt(0.90, 0.56), pt(0.84, 0.78), pt(0.50, 0.82))
    head_pts += cubic(pt(0.50, 0.82), pt(0.16, 0.78), pt(0.10, 0.56), pt(0.20, 0.42))

    draw.polygon(head_pts, fill=(139, 92, 246, 255))

    inner_white = (255, 255, 255, 230)
    draw.polygon([pt(0.23, 0.38), pt(0.22, 0.24), pt(0.36, 0.34)], fill=inner_white)
    draw.polygon([pt(0.77, 0.38), pt(0.78, 0.24), pt(0.64, 0.34)], fill=inner_white)

    white = (255, 255, 255, 255)
    w_width = max(2, int(span * 0.032))
    draw.line([pt(0.08, 0.54), pt(0.30, 0.57)], fill=white, width=w_width)
    draw.line([pt(0.10, 0.65), pt(0.32, 0.63)], fill=white, width=w_width)
    draw.line([pt(0.92, 0.54), pt(0.70, 0.57)], fill=white, width=w_width)
    draw.line([pt(0.90, 0.65), pt(0.68, 0.63)], fill=white, width=w_width)

    eye_r = span * 0.048
    for ex, ey in [pt(0.36, 0.52), pt(0.64, 0.52)]:
        draw.ellipse([ex - eye_r, ey - eye_r, ex + eye_r, ey + eye_r], fill=white)

    draw.polygon([pt(0.46, 0.62), pt(0.54, 0.62), pt(0.50, 0.67)], fill=white)

    out = img.resize((size, size), Image.Resampling.LANCZOS)
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    out.save(out_path, "PNG")


if __name__ == "__main__":
    render_cat_icon("app/assets/icon/mewmer.png", 1024, pad_ratio=0.10)
    render_cat_icon(
        "app/android/app/src/main/res/drawable-xhdpi/splash_icon.png",
        192,
        pad_ratio=0.08,
    )
