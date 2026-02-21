import math
import sys

palette = [
    (140, 143, 174), # 1
    (88, 69, 99),   # 2
    (62, 33, 55),   # 3
    (154, 99, 72),  # 4
    (215, 155, 125), # 5
    (245, 237, 186), # 6
    (192, 199, 65),  # 7
    (100, 125, 52),  # 8
    (228, 148, 58),  # 9
    (157, 48, 59),   # 10
    (210, 100, 113), # 11
    (112, 55, 127),  # 12
    (126, 196, 193), # 13
    (52, 133, 157),  # 14
    (23, 67, 75),    # 15
    (31, 14, 28)     # 16
]

def closest_color(r, g, b):
    # Inputs are 0-1
    r *= 255
    g *= 255
    b *= 255
    min_dist = float('inf')
    best_idx = -1
    for i, p in enumerate(palette):
        dist = math.sqrt((r-p[0])**2 + (g-p[1])**2 + (b-p[2])**2)
        if dist < min_dist:
            min_dist = dist
            best_idx = i + 1
    return best_idx

if __name__ == "__main__":
    if len(sys.argv) == 4:
        r = float(sys.argv[1])
        g = float(sys.argv[2])
        b = float(sys.argv[3])
        print(closest_color(r, g, b))
