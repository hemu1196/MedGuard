import math
from PIL import Image, ImageDraw, ImageFilter

def create_shield_path(width, height, margin=0.12):
    # Safe bounds inside width x height
    w = width
    h = height
    
    cx = w / 2.0
    top_y = h * margin
    bottom_y = h * (1.0 - margin)
    left_x = w * margin
    right_x = w * (1.0 - margin)
    
    # Shield shape points (supersampled coordinates)
    # We construct a fine polygon using bezier-like interpolation
    points = []
    
    # Top edge with slight dip in center or flat with rounded shoulders
    # Left shoulder -> top dip -> Right shoulder
    top_control_y = top_y + (h * 0.03)
    
    # Generate points around shield boundary:
    # 1. Top edge (left to right)
    steps = 50
    for i in range(steps + 1):
        t = i / steps
        x = left_x + t * (right_x - left_x)
        # Dip in center (t=0.5 -> max dip)
        dip = math.sin(t * math.pi) * (h * 0.025)
        y = top_y + dip
        points.append((x, y))
        
    # 2. Right edge down to bottom tip
    for i in range(1, steps + 1):
        t = i / steps
        # Curve out then down to bottom tip (cx, bottom_y)
        # Cubic bezier from (right_x, top_y + dip) to (cx, bottom_y)
        # Control points: P0=(right_x, top_y), P1=(right_x + w*0.02, h*0.55), P2=(right_x - w*0.08, h*0.88), P3=(cx, bottom_y)
        p0 = (right_x, top_y + (h * 0.025))
        p1 = (right_x, h * 0.55)
        p2 = (cx + (w * 0.25), bottom_y - (h * 0.05))
        p3 = (cx, bottom_y)
        
        bx = (1-t)**3 * p0[0] + 3*(1-t)**2*t * p1[0] + 3*(1-t)*t**2 * p2[0] + t**3 * p3[0]
        by = (1-t)**3 * p0[1] + 3*(1-t)**2*t * p1[1] + 3*(1-t)*t**2 * p2[1] + t**3 * p3[1]
        points.append((bx, by))
        
    # 3. Bottom tip up to left shoulder
    for i in range(1, steps + 1):
        t = i / steps
        p0 = (cx, bottom_y)
        p1 = (cx - (w * 0.25), bottom_y - (h * 0.05))
        p2 = (left_x, h * 0.55)
        p3 = (left_x, top_y + (h * 0.025))
        
        bx = (1-t)**3 * p0[0] + 3*(1-t)**2*t * p1[0] + 3*(1-t)*t**2 * p2[0] + t**3 * p3[0]
        by = (1-t)**3 * p0[1] + 3*(1-t)**2*t * p1[1] + 3*(1-t)*t**2 * p2[1] + t**3 * p3[1]
        points.append((bx, by))
        
    return points

def create_medical_cross(cx, cy, arm_length, arm_width, radius=12):
    # Returns 12-vertex polygon for medical cross with rounded corners
    # Horizontal bar: x from cx-arm_length to cx+arm_length, y from cy-arm_width to cy+arm_width
    # Vertical bar: x from cx-arm_width to cx+arm_width, y from cy-arm_length to cy+arm_length
    w = arm_width / 2.0
    l = arm_length / 2.0
    
    # Cross polygon points starting from top-left of top arm clockwise:
    raw_points = [
        (cx - w, cy - l), # top arm top left
        (cx + w, cy - l), # top arm top right
        (cx + w, cy - w), # inner corner top right
        (cx + l, cy - w), # right arm top right
        (cx + l, cy + w), # right arm bottom right
        (cx + w, cy + w), # inner corner bottom right
        (cx + w, cy + l), # bottom arm bottom right
        (cx - w, cy + l), # bottom arm bottom left
        (cx - w, cy + w), # inner corner bottom left
        (cx - l, cy + w), # left arm bottom left
        (cx - l, cy - w), # left arm top left
        (cx - w, cy - w), # inner corner top left
    ]
    return raw_points

def draw_gradient_fill(draw_img, points, color_top, color_bottom):
    # Render shape filled with vertical linear gradient
    mask = Image.new('L', draw_img.size, 0)
    mask_draw = ImageDraw.Draw(mask)
    mask_draw.polygon(points, fill=255)
    
    # Create gradient image
    gradient = Image.new('RGBA', draw_img.size)
    g_draw = ImageDraw.Draw(gradient)
    
    min_y = min(p[1] for p in points)
    max_y = max(p[1] for p in points)
    h_span = max(1, max_y - min_y)
    
    for y in range(int(min_y), int(max_y) + 1):
        t = (y - min_y) / h_span
        r = int(color_top[0] * (1 - t) + color_bottom[0] * t)
        g = int(color_top[1] * (1 - t) + color_bottom[1] * t)
        b = int(color_top[2] * (1 - t) + color_bottom[2] * t)
        a = int(color_top[3] * (1 - t) + color_bottom[3] * t) if len(color_top) > 3 else 255
        g_draw.line([(0, y), (draw_img.width, y)], fill=(r, g, b, a))
        
    gradient.putalpha(mask)
    draw_img.alpha_composite(gradient)

def generate_master_icon(size=1024):
    # Supersampling 4x for ultra smooth curves
    ss = 4
    S = size * ss
    
    # Colors (Rich Medical Royal Blue / Teal Gradient)
    BLUE_TOP = (0, 168, 150, 255)      # Vibrant Cyan/Teal (from ref design)
    BLUE_BOTTOM = (10, 110, 150, 255)  # Royal Deep Medical Blue
    BG_COLOR = (15, 23, 42, 255)       # Dark Navy background or Light Background
    
    # App Icon Image (Full Canvas with background)
    full_img = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    
    # Background rounded rectangle or gradient
    bg_img = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    bg_draw = ImageDraw.Draw(bg_img)
    
    # Gradient background for standard app icon (00A896 to 0A6E96 or 0F172A to 1E293B)
    # Royal Blue Gradient Background
    for y in range(S):
        t = y / S
        r = int(14 * (1-t) + 10 * t)
        g = int(165 * (1-t) + 100 * t)
        b = int(160 * (1-t) + 140 * t)
        bg_draw.line([(0, y), (S, y)], fill=(r, g, b, 255))
        
    full_img.paste(bg_img)
    
    # Shield shape points
    shield_pts = create_shield_path(S, S, margin=0.15)
    
    # Draw shield with gradient
    draw_gradient_fill(full_img, shield_pts, (0, 206, 184, 255), (0, 128, 160, 255))
    
    # Shield subtle inner border / highlight
    inner_shield_pts = create_shield_path(S, S, margin=0.165)
    # Inner subtle glow edge
    
    # Medical Cross in center
    cx = S / 2.0
    cy = S * 0.48 # slightly above geometric center for visual balance inside shield
    cross_pts = create_medical_cross(cx, cy, arm_length=S*0.38, arm_width=S*0.13)
    
    cross_img = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    cross_draw = ImageDraw.Draw(cross_img)
    cross_draw.polygon(cross_pts, fill=(255, 255, 255, 255))
    
    full_img.alpha_composite(cross_img)
    
    # Downsample with Lanczos to master size 1024x1024
    master_icon = full_img.resize((size, size), Image.LANCZOS)
    return master_icon

def generate_adaptive_foreground(size=1024):
    # Android Adaptive foreground (transparent background, shield centered within 66% diameter)
    ss = 4
    S = size * ss
    
    full_img = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    
    # Margin 0.22 ensures shield is safely within inner 66% safe zone (safe area = margin 0.17..0.83)
    shield_pts = create_shield_path(S, S, margin=0.22)
    
    draw_gradient_fill(full_img, shield_pts, (0, 206, 184, 255), (0, 128, 160, 255))
    
    cx = S / 2.0
    cy = S * 0.485
    cross_pts = create_medical_cross(cx, cy, arm_length=S*0.30, arm_width=S*0.10)
    
    cross_img = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    cross_draw = ImageDraw.Draw(cross_img)
    cross_draw.polygon(cross_pts, fill=(255, 255, 255, 255))
    
    full_img.alpha_composite(cross_img)
    
    fg_icon = full_img.resize((size, size), Image.LANCZOS)
    return fg_icon

def generate_adaptive_background(size=1024):
    # Android Adaptive background (solid gradient image)
    img = Image.new('RGBA', (size, size), (0, 0, 0, 255))
    draw = ImageDraw.Draw(img)
    for y in range(size):
        t = y / size
        r = int(14 * (1-t) + 8 * t)
        g = int(140 * (1-t) + 70 * t)
        b = int(145 * (1-t) + 105 * t)
        draw.line([(0, y), (size, y)], fill=(r, g, b, 255))
    return img

import os
os.makedirs("assets/icon", exist_ok=True)

icon = generate_master_icon(1024)
icon.save("assets/icon/app_icon.png")

fg = generate_adaptive_foreground(1024)
fg.save("assets/icon/ic_launcher_foreground.png")

bg = generate_adaptive_background(1024)
bg.save("assets/icon/ic_launcher_background.png")

print("Generated master icon assets in assets/icon/")
