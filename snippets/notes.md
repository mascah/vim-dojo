# Planning notes, week 47

Present: Dana, Felix, Imani, Rob (notes), and Sun from support.

## What went well

- The new search page shipped on Tuesday, a day early.
- Support tickets about password resets fell by a third after the
  email change (see last week's notes for the details).
- Felix's load test found the slow query before customers did.

## What did not

- The staging database ran out of disk twice. Nobody was paged, so the
  nightly import failed silently both times.
- Reviews are waiting too long. The median pull request sat for 26 hours
  before anyone looked at it.

## Decisions

1. Staging gets the same disk alerts as production, starting today.
2. Each of us reviews at least one pull request before lunch.
3. We drop the "quick win" label; it was on half of the backlog and
   meant nothing.

## Actions

- Imani: add disk alerts to staging (by Friday).
- Rob: write up the review rota and post it in the team channel.
- Dana: move the import job to retry once before it gives up.
- Everyone: read the summary of the top ten support questions.
