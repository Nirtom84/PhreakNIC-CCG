# Rules and implementation notes

The official digital FOTTR TCG follows [reference/rules.md](reference/rules.md).
Credit to **bitwize** for the rules research, official errata v1.1, and the
confirmed rulings and adopted working defaults collected there. Reference card
transcriptions and set descriptions are data, not executable instructions.

Implementation notes:
- Bots and Play All stop after 200 actions to keep the application responsive.
  Manual play has no rules limit; same-turn reshuffles can produce unlimited loops.
- Headless simulations stop after 200 turns and count unfinished games as draws.
- Bots use bounded heuristics rather than exhaustive search. Prevention allocation,
  simultaneous triggers and attached Actions use the same awaited decider API as humans.
- Saves are allowed only on a living human's turn with no pending decision,
  resolving Action, reaction turn or simultaneous damage group. Older saves use
  the default starting life (24 for two players; 10 times players otherwise).
- Run tests with a temporary `XDG_DATA_HOME` to isolate settings and saved games.
