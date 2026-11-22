function! vim_dojo#drills#All() abort
  let drills = []
  let groups = {'objects': s:Objects(), 'repeat': s:Repeat(), 'jumps': s:Jumps()}
  for skill in ['objects', 'repeat', 'jumps']
    let tasks = groups[skill]
    for index in range(len(tasks))
      let task = tasks[index]
      let task.skill = skill
      let task.application = index >= 2
      let task.position = s:Position(task.lines, task.start)
      let task.expected = copy(task.lines)
      if has_key(task, 'replace')
        let [before, after] = task.replace
        let pattern = '\V' . escape(before, '\')
        let replacement = escape(after, '\&~')
        let context = get(task, 'on_lines_with', '')
        call map(task.expected, {_, line -> stridx(line, context) < 0
              \ ? line : substitute(line, pattern, replacement, 'g')})
      elseif has_key(task, 'delete_line')
        call filter(task.expected, {_, line -> line !=# task.delete_line})
      else
        let task.destination = s:Position(task.lines, task.find)[0]
      endif
    endfor
    call extend(drills, tasks)
  endfor
  return drills
endfunction

function! s:Position(lines, anchor) abort
  for index in range(len(a:lines))
    let column = stridx(a:lines[index], a:anchor)
    if column >= 0
      return [index + 1, column + 1]
    endif
  endfor
  throw 'Missing drill anchor: ' . a:anchor
endfunction

function! s:Objects() abort
  return [
        \ {'id': 'quoted-item', 'ft': 'python', 'start': 'widget',
        \  'goal': 'Change the first item’s name to "ratchet".',
        \  'lines': ['def load_items() -> list[Item]:',
        \            '    return [',
        \            '        Item("widget", 9.99, ["tools", "small"]),',
        \            '        Item("gadget", 24.50, ["tools"]),',
        \            '    ]'],
        \  'replace': ['"widget"', '"ratchet"'],
        \  'hint': 'A text object can target everything inside a pair of quotes.',
        \  'keys': 'ci"ratchet<Esc>',
        \  'why': 'ci" works anywhere inside the value, even if it contains spaces.'},
        \ {'id': 'shipping-status', 'ft': 'python', 'start': 'pickup',
        \  'goal': 'Change the shipping status to "ready to ship".',
        \  'lines': ['order = {',
        \            '    "customer": "Sam Lee",',
        \            '    "status": "awaiting pickup",',
        \            '}'],
        \  'replace': ['"awaiting pickup"', '"ready to ship"'],
        \  'hint': 'Use the surrounding quotes to target both words in the value.',
        \  'keys': 'ci"ready to ship<Esc>',
        \  'why': 'ci" changes the whole value even when the cursor is on its second word.'},
        \ {'id': 'catalog-string', 'ft': 'go', 'start': 'return []Item', 'locate': 1,
        \  'goal': 'In the catalog below, rename "bulk spacer" to "steel washer".',
        \  'lines': ['func loadItems() []Item {',
        \            '    return []Item{',
        \            '        {Name: "widget", Price: 9.99, Tags: []string{"tools", "small"}},',
        \            '        {Name: "bulk spacer", Price: 3.25, Tags: []string{"tools"}},',
        \            '        {Name: "gadget", Price: 24.50, Tags: []string{"tools"}},',
        \            '    }',
        \            '}'],
        \  'replace': ['"bulk spacer"', '"steel washer"'],
        \  'hint': 'Find the item by name, then change the whole quoted value.',
        \  'keys': '/bulk spacer<Enter>ci"steel washer<Esc>',
        \  'why': 'The quote marks define the edit even when the name spans two words.'},
        \ {'id': 'quoted-endpoint', 'ft': 'python', 'start': 'API_URL',
        \  'goal': 'Change API_URL to "https://api.example.test/v2".',
        \  'lines': ['API_URL = "http://localhost:8080/api"',
        \            'HEALTH_URL = "http://localhost:8080/health"',
        \            'TIMEOUT = 15'],
        \  'replace': ['"http://localhost:8080/api"', '"https://api.example.test/v2"'],
        \  'hint': 'Change everything inside the double quotes around the URL.',
        \  'keys': 'f"lci"https://api.example.test/v2<Esc>',
        \  'why': 'The same object covers punctuation and slashes inside the quotes.'},
        \ {'id': 'call-arguments', 'ft': 'python', 'start': 'def total_price',
        \  'goal': 'Make sum() take prices as its only argument in total_price().',
        \  'lines': ['def total_price(items: list[Item]) -> float:',
        \            '    prices = [item.price for item in items]',
        \            '    return sum(float(item.price) for item in items)'],
        \  'replace': ['float(item.price) for item in items', 'prices'],
        \  'hint': 'Target the inside of the outer parentheses from within sum().',
        \  'keys': '/) for item<Enter>lci(prices<Esc>',
        \  'why': 'ci( changes a parenthesized expression, including any nested calls.'},
        \ ]
endfunction

function! s:Repeat() abort
  return [
        \ {'id': 'pending-jobs', 'ft': 'python', 'start': 'pending',
        \  'goal': 'Mark all three jobs as queued.',
        \  'lines': ['status["import"] = "pending"',
        \            'status["export"] = "pending"',
        \            'status["backup"] = "pending"'],
        \  'replace': ['"pending"', '"queued"'],
        \  'hint': 'Make one complete change. Move to the next value and repeat it.',
        \  'keys': 'ciwqueued<Esc>j.j.',
        \  'why': 'Dot repeats the change, including the text you typed in Insert mode.'},
        \ {'id': 'retry-counts', 'ft': 'go', 'start': 'maxRetries: 2',
        \  'goal': 'Set maxRetries to 5 for all three workers.',
        \  'lines': ['workers := []Worker{',
        \            '    {name: "api", maxRetries: 2},',
        \            '    {name: "log", maxRetries: 2},',
        \            '    {name: "job", maxRetries: 2},',
        \            '}'],
        \  'replace': ['maxRetries: 2', 'maxRetries: 5'],
        \  'hint': 'Replace the first digit, then repeat that edit on the next two.',
        \  'keys': 'f2r5j.j.',
        \  'why': 'A single-character replacement is also a change that dot can repeat.'},
        \ {'id': 'strip-debug-args', 'ft': 'python', 'start': 'def dispatch',
        \  'goal': 'Remove the final debug=True argument from each publish() call.',
        \  'lines': ['def dispatch(event, config):',
        \            '    publish(event.id, debug=True)',
        \            '    if config.save_archive:',
        \            '        publish(event.archive_id, debug=True)',
        \            '    audit(event.id, debug=True)',
        \            '    publish(config.default_id, debug=True)'],
        \  'replace': [', debug=True', ''], 'on_lines_with': 'publish(',
        \  'hint': 'Delete from the comma up to the closing paren, then repeat at the other publish calls.',
        \  'keys': 'At each publish() comma, use dt) for the first edit and . for the rest.',
        \  'why': 'Dot repeats the delete and its motion, even when the calls are on scattered lines.'},
        \ {'id': 'unskip-tests', 'ft': 'go', 'start': 'func TestInventory',
        \  'goal': 'Remove all temporary skips and keep the test bodies.',
        \  'lines': ['func TestInventory(t *testing.T) {',
        \            '    t.Skip("temporary")',
        \            '    checkInventory(t)',
        \            '}',
        \            '',
        \            'func TestTotals(t *testing.T) {',
        \            '    t.Skip("temporary")',
        \            '    checkTotals(t)',
        \            '}'],
        \  'delete_line': '    t.Skip("temporary")',
        \  'hint': 'Delete one whole skip line, then find the next skip and repeat.',
        \  'keys': '/t\.Skip<Enter>dd/t\.Skip<Enter>.',
        \  'why': 'Search can get you to the next edit without changing what dot repeats.'},
        \ ]
endfunction

function! s:Jumps() abort
  return [
        \ {'id': 'find-loader', 'ft': 'go', 'start': 'items :=', 'find': 'func loadItems',
        \  'goal': 'Go to the definition of loadItems from its call in main().',
        \  'lines': ['func loadItems() []Item {',
        \            '    return []Item{{Name: "widget", Price: 9.99}}',
        \            '}',
        \            '',
        \            'func main() {',
        \            '    items := loadItems()',
        \            '    fmt.Println(totalPrice(items))',
        \            '}'],
        \  'hint': 'Search backward for the function declaration.',
        \  'keys': '?^func loadItems<Enter>, then Ctrl-O after checking the first stop.',
        \  'why': 'Ctrl-O uses the jump list to return to the call site.'},
        \ {'id': 'find-describe', 'ft': 'python', 'start': 'print(describe', 'find': 'def describe',
        \  'goal': 'Go to the definition of describe from its call in render().',
        \  'lines': ['def render(items):',
        \            '    for item in items:',
        \            '        print(describe(item))',
        \            '',
        \            'def describe(item):',
        \            '    return f"{item.name}: ${item.price:.2f}"'],
        \  'hint': 'Search forward for the line that defines the helper.',
        \  'keys': '/^def describe<Enter>, then Ctrl-O after checking the first stop.',
        \  'why': 'Searching for the declaration skips over calls with the same name.'},
        \ {'id': 'find-fallback', 'ft': 'go', 'start': 'fmt.Println(fallback', 'find': 'func fallback',
        \  'goal': 'From the print call, jump to the definition of fallback().',
        \  'lines': ['func fallback() string {',
        \            '    return "default"',
        \            '}',
        \            '',
        \            '// Use fallback when a request times out.',
        \            'func printResult() {',
        \            '    value, err := fetch()',
        \            '    if err != nil {',
        \            '        fmt.Println(fallback())',
        \            '        return',
        \            '    }',
        \            '    fmt.Println(value)',
        \            '}'],
        \  'hint': 'Include the Go declaration keyword in a backward search.',
        \  'keys': '?^func fallback<Enter>, then Ctrl-O after checking the first stop.',
        \  'why': 'A precise search skips the comment and Ctrl-O jumps back into the error branch.'},
        \ {'id': 'find-total', 'ft': 'python', 'start': 'print(total_price', 'find': 'def total_price',
        \  'goal': 'From the print call, jump to the definition of total_price().',
        \  'lines': ['def total_price(items):',
        \            '    return sum(item.price for item in items)',
        \            '',
        \            'def render(items):',
        \            '    value = total_price(items)',
        \            '    if value > 0:',
        \            '        print(total_price(items))',
        \            '',
        \            '# total_price is also used by the daily summary.'],
        \  'hint': 'Search for the definition so the other call is skipped.',
        \  'keys': '?^def total_price<Enter>, then Ctrl-O after checking the first stop.',
        \  'why': 'The jump list returns to the exact call you were inspecting.'},
        \ ]
endfunction
