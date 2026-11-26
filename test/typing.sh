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
function! Drill(id) abort
  for technique in vim_dojo#drills#Techniques()
    for drill in technique.drills
      if drill.id ==# a:id
        call vim_dojo#Start([{'kind': 'free', 'technique': '', 'goals': [drill]}])
      endif
    endfor
  endfor
endfunction
source $root/dojo.vim
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
check startup 'Start today'

# real-typing-count
tmux send-keys -t "$session" ":call Drill('find-equals')" Enter
check real-typing-count 'Move onto the = sign'
slowly f =
# Two keys: a dropped key or a counted <CursorHold> would show another count.
check real-typing-count 'Last: 2 keys · par 2 · clean'

# dot-still-one: a burst, then single keys after pauses.
tmux send-keys -t "$session" ":call Drill('pending-jobs')" Enter
check dot-still-one 'Mark all three jobs as queued'
sleep 0.3
tmux send-keys -t "$session" ciwqueued
slowly Escape j . j .
check dot-still-one 'Last: 14 keys · par 14 · clean'

tmux send-keys -t "$session" ':qa!' Enter
[ "$failed" = 0 ] && echo 'typing check passed'
exit "$failed"
