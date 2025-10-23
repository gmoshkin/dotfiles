def inspect(l, start, count):
    res = []

    if count <= 0:
        for e in l:
            res.append(f' {e} ')
        return str.join('', res)

    for e in l[:start]:
        res.append(f' {e} ')

    if count == 1:
        e = l[start]
        res.append(f'[{e}]')
    elif count > 0:
        e = l[start]
        res.append(f'[{e} ')

    for e in l[start+1:start+count-1]:
        res.append(f' {e} ')

    if count > 1:
        e = l[start+count-1]
        res.append(f' {e}]')

    for e in l[start+count:]:
        res.append(f' {e} ')

    return str.join('', res)


def quicksort_helper(l, start, count):
    if count < 2:
        return

    mid = start + count // 2
    p = l[mid]
    # print('mid  ', inspect(l, mid, 1), f'|  {mid}, {1}')

    i = start
    j = start + count - 1

    while True:
        # print('     ', inspect(l, i, j - i + 1))
        while l[i] < p:
            i += 1
            # print('     ', inspect(l, i, j - i + 1))
        while p < l[j]:
            j -= 1
            # print('     ', inspect(l, i, j - i + 1))

        if i >= j:
            break

        l[i], l[j] = l[j], l[i]
        # print()
        # print('     ', inspect(l, i, 1))
        # print('     ', inspect(l, j, 1))
        # print()

        i += 1
        j -= 1

    left_len = i - start
    # print('left ', inspect(l, start, left_len), f'|  {start}, {left_len}')
    quicksort_helper(l, start, left_len)
    # print('right', inspect(l, i, count - left_len), f'|  {i}, {count - left_len}')
    quicksort_helper(l, i, count - left_len)

def quick_sort(l):
    quicksort_helper(l, 0, len(l))


if __name__ == '__main__':

    l = [3, 1, 4, 1, 5, 9, 2, 6, 5]

    print(l)
    quick_sort(l)
    print(l)

    l = []
    for i in range(100):
        l.append(i)

    import random

    for i in range(10000):
        tmp = l[:]
        random.shuffle(tmp)
        assert tmp != l
        quick_sort(tmp)
        assert tmp == l, f"{tmp}"


