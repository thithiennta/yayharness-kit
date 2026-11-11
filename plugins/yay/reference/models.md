# Model and effort routing

Each step that runs a subagent can use a different model and reasoning effort. `yayh` resolves the choice from `.yay/config.json` (and `.yay/local.json`, which wins key by key), so skills and workflow scripts never pick a model by hand. With no `models` key, every step inherits the session's model, the same as before routing existed.

## Tiers

| Tier | Model | Effort | For |
|---|---|---|---|
| `veryfast` | sonnet | medium | read-only fan-out, lookups, search summaries |
| `fast` | opus | low | edits whose judgement is already made |
| `balanced` | opus | medium | review, diagnosis, planning, building |
| `deep` | opus | high | one-shot synthesis, large items |

`sonnet` and `opus` are the Agent and Workflow aliases for the current Sonnet and Opus models. Override a tier, or add one, under `models.tiers.<name>` (`{ "model": …, "effort": … }`). A field you leave out keeps the built-in tier's value. Models: `sonnet`, `opus`. Efforts: `low`, `medium`, `high`, `xhigh`, `max`.

## Steps

| Step | Where it runs | Recommended |
|---|---|---|
| `scout` | knowledge-init, knowledge-update, test-init, e2e-init scouts | `veryfast` |
| `web-research` | `/yay:roadmap --web` research agent | `veryfast` |
| `feasibility` | `/yay:brainstorm` Explore agent per option | `veryfast` |
| `revise` | autopilot: apply decision-sheet answers | `fast` |
| `resolve` | autopilot: fix review findings, push, PR | `fast` |
| `review` | `yay:code-reviewer` (implement, fix, autopilot) | `balanced` |
| `hypothesis` | `/yay:debug` hypothesis checkers | `balanced` |
| `portfolio-research` | `/yay:roadmap --multi-agent` owner research | `balanced` |
| `cowork` | `/yay:roadmap --multi-agent` co-work round | `balanced` |
| `prepare` | autopilot: brainstorm and plan an item | `balanced` |
| `implement` | autopilot: build an item | `balanced` |
| `synthesis` | `/yay:roadmap --multi-agent` final schedule | `deep` |
| `task` | `/yay:implement` per-task delegation | `inherit` |

The rule behind the recommendations: spend where a mistake spreads downstream (a plan, the only review of an unattended build), and save where a step only gathers facts the main session checks anyway.

To opt in, copy this into `.yay/config.json` and change what you need:
```json
"models": {
  "steps": {
    "scout": "veryfast", "web-research": "veryfast", "feasibility": "veryfast",
    "revise": "fast", "resolve": "fast",
    "review": "balanced", "hypothesis": "balanced",
    "portfolio-research": "balanced", "cowork": "balanced",
    "prepare": "balanced", "implement": "balanced",
    "synthesis": "deep", "task": "inherit"
  }
}
```
A step's value is a tier name, `inherit` (the session's model), or an inline `{ "model": …, "effort": … }`.

## Size bump

`prepare`, `implement`, `review` and `task` act on a roadmap item, so the item's size moves their tier along `veryfast → fast → balanced → deep`. The move is `models.sizeBump` (default `{ "S": -1, "M": 0, "L": 1 }`), clamped at both ends. `balanced` therefore becomes `fast` for an S item and `deep` for an L item. A step set to `inherit`, an inline object, or a task's tier tag is never bumped.

## Resolving

`yayh model resolve <step> [--size=S|M|L] [--tier=<tier>] [--plan=P-n] [--task=Tn]` prints one JSON line, such as `{"model":"opus","effort":"medium"}`, or `{}` to inherit.
- `--plan` takes the size from the plan's `roadmap:` item. An explicit `--size` wins.
- `--task` (with `--plan`) reads the task's `[tier: <name>]` tag.
- `--tier` sets the tier directly. It wins over the step's tier and isn't bumped.

`yayh model table` prints every step's tier, model and effort. `yayh config validate` checks the `models` block.

**Skills** run the resolve command before spawning, then pass `model` and `effort` from its output to the Agent tool. When the output is `{}`, they pass neither.

**Workflow scripts** take `yayh model table --json` as `args.models`. Their `route(step, size)` helper applies the same rules and spreads `{ model, effort }` into each `agent()` call.

## Per-task delegation in `/yay:implement`

A plan task may end with a tier tag: `- [ ] T3 Rename the option — \`includes/Plugin.php\` [tier: veryfast]`. `/yay:plan` adds a tag only when a task is clearly mechanical (`veryfast`: renames, copy, config) or clearly hard (`deep`). Most tasks have none. `yayh plan check` rejects unknown tiers.

In the task loop, `yayh model resolve task --plan=P-n --task=Tn`:
- `{}`: do the task inline, as always.
- Anything else: spawn one `general-purpose` agent with that model and effort. Its brief is:
  - the worktree path, the plan path, and the task's full text with its `Reuse:` line
  - the code rules (`${CLAUDE_PLUGIN_ROOT}/reference/code-rules.md`)
  - "do exactly this task, run the checks it touches, don't tick or commit; return the files changed, checks run and their results, and any decision you made".

  The main session then reviews the diff, re-runs the checks, ticks the task and commits as usual. It writes the backlog notes too.

Setting `models.steps.task` to a tier delegates every task. The default is `inherit`.
