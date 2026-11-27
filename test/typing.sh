#!/bin/sh
# Types real keys into Vim through tmux, which the headless suite cannot do:
# feedkeys() never shows how a terminal delivers keys after a pause.
# Run from anywhere with sh test/typing.sh. Skipped where tmux is missing.
if ! command -v tmux >/dev/null 2>&1; then
  echo 'typing check skipped: no tmux'
  exit 0
fi
root=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
session=dojo-typing-$$
trap 'tmux kill-session -t "$session" 2>/dev/null; rm -rf "$tmp"' EXIT
failed=0

cat > "$tmp/vimrc" <<EOF
set updatetime=100
autocmd CursorHold * let g:held = 1
let g:vim_dojo_state_dir = '$tmp/state'
let g:vim_dojo_demo_delay = 0
function! Goal(drill) abort
  call vim_dojo#Start({'kind': 'free', 'lesson': '', 'goals': [a:drill]})
endfunction
set runtimepath^=$root
EOF

screen() {
  tmux capture-pane -p -t "$session"
}

# Waits up to five seconds for the screen to match a pattern.
wait_for() {
  for _ in $(seq 50); do
    screen | grep -q -- "$1" && return 0
    sleep 0.1
  done
  return 1
}

check() {
  if ! wait_for "$2"; then
    echo "FAIL $1: no '$2' on screen"
    screen
    failed=1
  fi
}

# Each key comes after a pause longer than updatetime.
slowly() {
  for key in "$@"; do
    sleep 0.3
    tmux send-keys -t "$session" "$key"
  done
}

tmux new-session -d -s "$session" -x 100 -y 30 "vim -Nu '$tmp/vimrc' -i NONE -n"
check startup '^~'

# real-typing-count
tmux send-keys -t "$session" ":call Goal({'id': 'find-equals', 'ft': 'python', 'lines': ['config[\"timeout\"] = 30'], 'goal': 'Move onto the = sign.', 'solution': 'f='})" Enter
check real-typing-count 'Move onto the = sign'
slowly f =
# Two keys: a dropped key or a counted <CursorHold> would show another count.
check real-typing-count 'Last: 2 keys · par 2 · clean'

# dot-still-one: a burst, then single keys after pauses.
tmux send-keys -t "$session" ":call Goal({'id': 'pending-jobs', 'ft': 'python', 'start': 'pending', 'goal': 'Mark all three jobs as queued.', 'lines': ['status[\"import\"] = \"pending\"', 'status[\"export\"] = \"pending\"', 'status[\"backup\"] = \"pending\"'], 'solution': 'ciwqueued<Esc>j.j.'})" Enter
check dot-still-one 'Mark all three jobs as queued'
sleep 0.3
tmux send-keys -t "$session" ciwqueued
slowly Escape j . j .
check dot-still-one 'Last: 14 keys · par 14 · clean'

# scroll-pinned: Ctrl-D moves the pinned eight lines whatever the window's
# height, after the panel has resized.
tmux send-keys -t "$session" ":call Goal({'id': 'scroll', 'ft': 'text', 'start': 'row 5', 'goal': 'Scroll down.', 'lines': map(range(1, 60), '\"row \" . v:val'), 'solution': '<C-D>'})" Enter
check scroll-pinned 'Scroll down'
slowly C-d
check scroll-pinned 'Last: 1 keys · par 1 · clean'

tmux send-keys -t "$session" ':qa!' Enter

# shell-round, end to end: the shell starts Vim, here a wrapper with the
# same vimrc, on a custom lesson of ten goals; solving them all returns to
# the map with the summary and the lesson shaky.
if command -v go >/dev/null 2>&1 && (cd "$root" && go build -o "$tmp/dojo" .); then
  mkdir -p "$tmp/bin" "$tmp/drills"
  printf '#!/bin/sh\nexec %s -Nu %s -i NONE -n "$@"\n' "$(command -v vim)" "$tmp/vimrc" > "$tmp/bin/vim"
  chmod +x "$tmp/bin/vim"
  echo '{"id": "zz-beta", "goal": "Change alpha to beta.", "lines": ["alpha"], "expected": ["beta"], "solution": "ciwbeta<Esc>"}' \
    > "$tmp/drills/beta.json"
  tmux kill-session -t "$session" 2>/dev/null
  tmux new-session -d -s "$session" -x 100 -y 30 \
    "PATH='$tmp/bin':\$PATH VIM_DOJO_ROOT='$root' VIM_DOJO_STATE_DIR='$tmp/shell' VIM_DOJO_DRILL_DIR='$tmp/drills' '$tmp/dojo'"
  check shell-map 'Start today'
  tmux send-keys -t "$session" G Enter
  check shell-round 'Learn  zz-beta  ·  1/10'
  for _ in $(seq 10); do
    tmux send-keys -t "$session" ciwbeta Escape
    sleep 0.2
  done
  check shell-round '10 of 10 clean'
  tmux send-keys -t "$session" Enter
  check shell-round 'Learn  zz-beta  ·  10 of 10 clean  ·  .*passed'
  check shell-round '◐ zz-beta  *shaky  *due tomorrow'
  # Quitting Vim mid-round returns too, and says so.
  tmux send-keys -t "$session" Enter
  check shell-round 'Review  zz-beta  ·  1/10'
  tmux send-keys -t "$session" ':qa!' Enter
  check shell-round 'Left Review  zz-beta after 0 of 10 goals'
  # nothing-raw-persisted
  if grep -rq 'ciw\|beta<' "$tmp/shell"; then
    echo 'FAIL nothing-raw-persisted: typed keys in the state directory'
    failed=1
  fi
  tmux send-keys -t "$session" q
else
  echo 'shell check skipped: no go'
fi
[ "$failed" = 0 ] && echo 'typing check passed'
exit "$failed"
