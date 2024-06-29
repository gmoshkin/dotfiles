def diff(p, q):
    x0, y0 = p
    x1, y1 = q
    return x1 - x0, y1 - y0

def get_k(p, q):
    v = diff(p, q)
    return v[1] / v[0]

get_b = lambda p, q: p[1] - get_k(p, q) * p[0]

get_x = lambda k0, k1, b0, b1: (b1 - b0) / (k0 - k1)
get_y = lambda k, x, b: k * x + b

def get_point(k0, k1, b0, b1):
    x =  get_x(k0, k1, b0, b1)
    return x, get_y(k0, x, b0)

p0 = 235.5, -122.4; q0 = 257, -110.7
p1 = 193.4, -73;    q1 = 204.2, -68
p2 = 127.3, 8.7;    q2 = 138.9, 13.1

intersection_01 = get_point(get_k(p0, q0), get_k(p1, q1), get_b(p0, q0), get_b(p1, q1))
intersection_12 = get_point(get_k(p1, q1), get_k(p2, q2), get_b(p1, q1), get_b(p2, q2))
intersection_02 = get_point(get_k(p0, q0), get_k(p2, q2), get_b(p0, q0), get_b(p2, q2))
print(f'{intersection_01=}')
print(f'{intersection_12=}')
print(f'{intersection_02=}')

points = [intersection_01, intersection_12, intersection_02]
xs = [p[0] for p in points]
ys = [p[1] for p in points]

intersection_mean = sum(xs)/len(xs), sum(ys)/len(ys)
print(f'{intersection_mean=}')
