import math

old_palette = {
    1: (140, 143, 174, "Slate Blue"),
    2: ( 88,  69,  99, "Deep Purple/Mauve"),
    3: ( 62,  33,  55, "Dark Plum"),
    4: (154,  99,  72, "Burnt Sienna"),
    5: (215, 155, 125, "Peach/Tan"),
    6: (245, 237, 186, "Pale Yellow"),
    7: (192, 199,  65, "Lichen Green"),
    8: (100, 125,  52, "Forest Green"),
    9: (228, 148,  58, "Amber/Orange"),
    10: (157,  48,  59, "Deep Red"),
    11: (210, 100, 113, "Rose"),
    12: (112,  55, 127, "Bright Purple"),
    13: (126, 196, 193, "Teal/Aqua"),
    14: ( 52, 133, 157, "Deep Blue-Teal"),
    15: ( 23,  67,  75, "Dark Petrol"),
    16: ( 31,  14,  28, "Obsidian Black")
}

new_palette = {
    1: (0, 0, 0, "Black"),
    2: (59, 34, 28, "Dark Brown"),
    3: (105, 48, 43, "Deep Red Brown"),
    4: (153, 52, 44, "Brick Red"),
    5: (184, 103, 53, "Burnt Orange"),
    6: (219, 163, 79, "Warm Gold"),
    7: (137, 153, 55, "Olive Green"),
    8: (76, 105, 51, "Forest Green"),
    9: (56, 59, 33, "Dark Olive"),
    10: (46, 76, 94, "Dark Teal Blue"),
    11: (92, 124, 148, "Steel Blue"),
    12: (138, 184, 172, "Sage Teal"),
    13: (194, 128, 128, "Dusty Rose"),
    14: (138, 67, 104, "Plum"),
    15: (79, 40, 78, "Deep Purple"),
    16: (38, 30, 46, "Dark Violet Black"),
    17: (62, 63, 69, "Charcoal"),
    18: (105, 97, 99, "Warm Gray"),
    19: (158, 158, 152, "Light Gray"),
    20: (230, 215, 204, "Warm White")
}

def dist(c1, c2):
    return math.sqrt(sum((a - b)**2 for a, b in zip(c1[:3], c2[:3])))

mapping = {}
for o_idx, o_c in old_palette.items():
    closest_idx = None
    min_dist = float('inf')
    for n_idx, n_c in new_palette.items():
        d = dist(o_c, n_c)
        if d < min_dist:
            min_dist = d
            closest_idx = n_idx
    mapping[o_idx] = closest_idx
    print(f"Old {o_idx:2d} ({o_c[3]}) -> New {closest_idx:2d} ({new_palette[closest_idx][3]}) dist: {min_dist:.1f}")

print("Mapping dict:")
print(mapping)
