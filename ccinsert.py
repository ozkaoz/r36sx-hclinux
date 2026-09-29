import io
src = io.open('CHANGELOG.md', encoding='utf-8').read()
entry = io.open('/tmp/cle.txt', encoding='utf-8').read()
src = src.replace('## 2026-09-26', '## 2026-09-26' + entry, 1)
io.open('CHANGELOG.md', 'w', encoding='utf-8').write(src)
print('CC_OK')
