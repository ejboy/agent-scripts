from pathlib import Path
import subprocess
import sys

if sys.platform != "darwin":
    print("Terminal AppleScript tests require macOS")
    sys.exit(0)

source = Path(__file__).with_name("slopstop").read_text()
start = source.index("if application \"Terminal\" is not running", source.index("collect_terminal_labels()"))
end = source.index("\n' >", start)
script = source[start:end].replace('if application "Terminal" is not running then return ""', '')
selected = 'tell application "Terminal" to set selectedTTYs to tty of selected tab of every window'
all_tabs = 'tell application "Terminal" to set windowTTYs to tty of every tab of every window'
titles = 'tell application "Terminal" to set windowTitles to custom title of every tab of every window'
confirmed = 'tell application "Terminal" to set confirmedTTYs to tty of every tab of every window'
script = script.replace(selected, 'set selectedTTYs to {"/dev/ttys001", missing value}')

cases = [
    ('set windowTTYs to {{"/dev/ttys001"}}',
     'set windowTitles to {{"café 🦡" & tab & "tab" & return & "CR" & linefeed & "/dev/ttys999" & tab & "fake" & character id 27 & "ESC" & character id 127 & "DEL" & character id 133 & "NEL" & character id 8232 & "LS" & character id 8233 & "PS"}}',
     ['/dev/ttys001\tcafé 🦡 tab CR /dev/ttys999 fake ESC DEL NEL LS PS']),
    ('set windowTTYs to {{"/dev/ttys001", "/dev/ttys002"}, missing value}',
     'set windowTitles to {{"selected title", ""}, missing value}',
     ['/dev/ttys001\tselected title', '/dev/ttys002\tTerminal.app · /dev/ttys002']),
    ('set windowTTYs to {{"/dev/ttys001", "/dev/ttys002"}, missing value}',
     'error "title lookup failed" number -1728',
     ['/dev/ttys001\tTerminal.app · /dev/ttys001', '/dev/ttys002\tTerminal.app · /dev/ttys002']),
    ('error "tab lookup failed" number -1728',
     'set windowTitles to {{"wrong background title"}, missing value}',
     ['/dev/ttys001\tTerminal.app · /dev/ttys001']),
]
cases = [(tab_query, title_query, 'set confirmedTTYs to windowTTYs', expected)
         for tab_query, title_query, expected in cases]
for confirmation in [
    'set confirmedTTYs to {{"/dev/ttys002", "/dev/ttys001"}, missing value}',
    'set confirmedTTYs to {{"/dev/ttys003", "/dev/ttys002"}, missing value}',
    'error "confirmation failed" number -1728',
]:
    cases.append((
        'set windowTTYs to {{"/dev/ttys001", "/dev/ttys002"}, missing value}',
        'set windowTitles to {{"wrong title", "another title"}, missing value}',
        confirmation,
        ['/dev/ttys001\tTerminal.app · /dev/ttys001', '/dev/ttys002\tTerminal.app · /dev/ttys002'],
    ))
for tab_query, title_query, confirmation, expected in cases:
    result = subprocess.run(
        ['/usr/bin/osascript', '-e', script.replace(all_tabs, tab_query).replace(titles, title_query).replace(confirmed, confirmation)],
        capture_output=True, text=True, check=True, timeout=5,
    )
    assert result.stdout.strip().splitlines() == expected, result.stdout
print('Terminal AppleScript tests passed')
