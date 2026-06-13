from pathlib import Path
print('START')
path = Path('D:/Symbiosis/backend/app/core/scheduler.py')
text = path.read_text(encoding='utf-8')
print('FOUND', 'async def run_allocation_and_get_commands' in text)
start = text.find('async def run_allocation_and_get_commands')
print('STARTIDX', start)
print(text[start:start+2200])
