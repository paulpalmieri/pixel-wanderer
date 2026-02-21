import os
import re
import math

# Target Palette (16 colors)
PALETTE = [
    (140, 143, 174), # 1: #8c8fae
    (88, 69, 99),   # 2: #584563
    (62, 33, 55),   # 3: #3e2137
    (154, 99, 72),  # 4: #9a6348
    (215, 155, 125), # 5: #d79b7d
    (245, 237, 186), # 6: #f5edba
    (192, 199, 65),  # 7: #c0c741
    (100, 125, 52),  # 8: #647d34
    (228, 148, 58),  # 9: #e4943a
    (157, 48,  59),  # 10: #9d303b
    (210, 100, 113), # 11: #d26471
    (112, 55,  127), # 12: #70377f
    (126, 196, 193), # 13: #7ec4c1
    (52,  133, 157), # 14: #34859d
    (23,  67,  75),  # 15: #17434b
    (31,  14,  28)   # 16: #1f0e1c
]

# Old Palette (64 colors) - extracted from core/palette.lua
OLD_PALETTE = [
    (0.047, 0.055, 0.090), (0.090, 0.110, 0.165), (0.145, 0.165, 0.220), (0.200, 0.210, 0.255), (0.255, 0.260, 0.290), (0.340, 0.345, 0.365),
    (0.165, 0.220, 0.145), (0.110, 0.165, 0.120), (0.145, 0.120, 0.130), (0.120, 0.137, 0.170), (0.310, 0.380, 0.480), (0.820, 0.620, 0.310),
    (0.850, 0.720, 0.530), (0.780, 0.790, 0.780), (0.220, 0.155, 0.165), (0.420, 0.310, 0.220), (0.310, 0.380, 0.200), (0.580, 0.420, 0.200),
    (0.840, 0.850, 0.870), (0.530, 0.540, 0.560), (0.260, 0.270, 0.290), (0.800, 0.830, 0.790), (0.490, 0.520, 0.490), (0.230, 0.260, 0.240),
    (0.830, 0.810, 0.780), (0.520, 0.490, 0.470), (0.270, 0.250, 0.240), (0.790, 0.820, 0.870), (0.480, 0.510, 0.570), (0.230, 0.250, 0.300),
    (0.220, 0.230, 0.180), (0.165, 0.180, 0.140), (0.310, 0.300, 0.280), (0.220, 0.165, 0.150), (0.110, 0.095, 0.095), (0.380, 0.480, 0.255),
    (0.075, 0.110, 0.075), (0.035, 0.030, 0.045), (0.980, 0.910, 0.160), (0.900, 0.780, 0.060), (0.660, 0.540, 0.040), (0.100, 0.500, 0.950),
    (0.950, 0.550, 0.100), (0.900, 0.700, 0.100), (0.850, 0.200, 0.150), (0.400, 0.450, 0.500), (0.200, 0.220, 0.260), (0.600, 0.630, 0.680),
    (0.784, 0.835, 0.725), (0.561, 0.682, 0.482), (0.322, 0.478, 0.322), (0.949, 0.835, 0.494), (0.910, 0.788, 0.627), (0.761, 0.584, 0.420),
    (0.478, 0.361, 0.259), (0.494, 0.784, 0.890), (0.769, 0.722, 0.831), (0.545, 0.471, 0.651), (0.353, 0.302, 0.431), (0.949, 0.647, 0.494),
    (0.722, 0.847, 0.910), (0.478, 0.686, 0.769), (0.290, 0.478, 0.561), (0.910, 0.722, 0.494)
]

def closest_color(r, g, b):
    # Inputs r, g, b are 0-1
    return find_best_idx(r*255, g*255, b*255)

def find_best_idx(r, g, b):
    min_dist = float('inf')
    best_idx = -1
    for i, p in enumerate(PALETTE):
        dist = math.sqrt((r-p[0])**2 + (g-p[1])**2 + (b-p[2])**2)
        if dist < min_dist:
            min_dist = dist
            best_idx = i + 1
    return best_idx

# Create mapping for old indices
INDEX_MAP = {}
for i, old in enumerate(OLD_PALETTE):
    INDEX_MAP[i+1] = closest_color(old[0], old[1], old[2])

def replace_in_file(filepath):
    with open(filepath, 'r') as f:
        content = f.read()

    # Skip core/palette.lua for special handling
    if 'core/palette.lua' in filepath:
        return

    # 1. Replace PAL[idx]
    def sub_pal(match):
        idx = int(match.group(1))
        if idx in INDEX_MAP:
            return f"PAL[{INDEX_MAP[idx]}]"
        return match.group(0)
    content = re.sub(r'PAL\[\s*([0-9]+)\s*\]', sub_pal, content)

    # 2. Replace set_color(idx, ...)
    def sub_set_color(match):
        idx = int(match.group(1))
        args = match.group(2)
        if idx in INDEX_MAP:
            return f"set_color({INDEX_MAP[idx]}{args})"
        return match.group(0)
    content = re.sub(r'set_color\(\s*([0-9]+)(\s*,[^)]*)?\)', sub_set_color, content)

    # 3. Replace love.graphics.setColor(r, g, b, ...)
    def sub_set_color_lib(match):
        r = float(match.group(1))
        g = float(match.group(2))
        b = float(match.group(3))
        remainder = match.group(4) or ""
        best_idx = closest_color(r, g, b)
        target_rgb = PALETTE[best_idx-1]
        tr, tg, tb = target_rgb[0]/255, target_rgb[1]/255, target_rgb[2]/255
        # If the file has access to set_color via palette, we might want to use that.
        # But for now, let's just update the RGB values to the exact palette values.
        return f"love.graphics.setColor({tr:.3f}, {tg:.3f}, {tb:.3f}{remainder})"
    content = re.sub(r'love\.graphics\.setColor\(\s*([0-9\.]+)\s*,\s*([0-9\.]+)\s*,\s*([0-9\.]+)\s*([^)]*)\)', sub_set_color_lib, content)

    # 4. Replace lerp_color(r1, g1, b1, r2, g2, b2, t)
    # This is trickier. Let's just snap the endpoints.
    def sub_lerp(match):
        r1, g1, b1 = float(match.group(1)), float(match.group(2)), float(match.group(3))
        r2, g2, b2 = float(match.group(4)), float(match.group(5)), float(match.group(6))
        t = match.group(7)
        c1 = PALETTE[closest_color(r1, g1, b1)-1]
        c2 = PALETTE[closest_color(r2, g2, b2)-1]
        return f"lerp_color({c1[0]/255:.3f}, {c1[1]/255:.3f}, {c1[2]/255:.3f}, {c2[0]/255:.3f}, {c2[1]/255:.3f}, {c2[2]/255:.3f}, {t})"
    content = re.sub(r'lerp_color\(\s*([0-9\.]+)\s*,\s*([0-9\.]+)\s*,\s*([0-9\.]+)\s*,\s*([0-9\.]+)\s*,\s*([0-9\.]+)\s*,\s*([0-9\.]+)\s*,\s*([^)]+)\)', sub_lerp, content)

    # 5. Handle special cases like the table in sys/player.lua: ({33, 34, 32})
    def sub_table(match):
        indices = match.group(1).split(',')
        new_indices = []
        for idx_str in indices:
            idx = int(idx_str.strip())
            if idx in INDEX_MAP:
                new_indices.append(str(INDEX_MAP[idx]))
            else:
                new_indices.append(idx_str.strip())
        return "{" + ", ".join(new_indices) + "}"
    
    content = re.sub(r'\{([0-9\s,]+)\}', sub_table, content)

    with open(filepath, 'w') as f:
        f.write(content)

# Define directories to scan
DIRS = ['core', 'sys', 'draw', 'gen']
FILES = ['main.lua']

for d in DIRS:
    for root, _, files in os.walk(d):
        for f in files:
            if f.endswith('.lua'):
                replace_in_file(os.path.join(root, f))

for f in FILES:
    if os.path.exists(f):
        replace_in_file(f)
