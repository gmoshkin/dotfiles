with open('slides.md', 'r') as f:
    data = f.read()

slides = data.split('<div style="page-break-after: always;"></div>')

for i, s in enumerate(slides):
    with open(f'slides/{i:03}.md', 'w') as f:
        f.write(f'{i: >80}\n')
        f.write(s)
