export const meta = {
  name: 'yay-roadmap-portfolio',
  description: 'One owner agent per Yay plugin researches its repo, the owners co-plan cross-plugin work, and one agent schedules every plugin into the shared sprints',
  whenToUse: 'Called by /yay:roadmap --multi-agent with args built by the skill; not for direct use',
  phases: [
    { title: 'Research', detail: 'one read-only owner agent per plugin' },
    { title: 'Co-work', detail: 'each owner answers asks and proposes joint work (skipped with rounds=1)' },
    { title: 'Synthesis', detail: 'one agent reconciles and schedules every plugin' },
  ],
}

// args (built by /yay:roadmap):
// { today, horizon, sprintLength, capacity, focus, web, rounds, models,
//   sprints: [{ n, start, end, freeze }],
//   plugins: [{ name, slug, path, repo, version, harnessed }] }
const A = args || {}
const PLUGINS = A.plugins || []
if (PLUGINS.length < 2) throw new Error('need at least two plugins')
const SPRINT_IDS = A.sprints.map(s => `S${s.n}`).concat(['later'])
const CAPACITY = A.capacity || 8

// Model routing (reference/models.md): A.models is `yayh model table --json`.
// route(step, size) -> { model, effort } options for agent(), or {} to inherit.
// Anything it can't determine (no table, an unknown step) runs on Opus medium.
function route(step, size) {
  const M = A.models
  const s = M && M.steps && M.steps[step]
  if (!s) return (M && M.tiers && M.tiers[M.fallback]) || { model: 'opus', effort: 'medium' }
  if (s.tier === 'inherit') return {}
  let tier = s.tier
  if (size && (M.sized || []).includes(step) && (M.order || []).includes(tier)) {
    const i = Math.min(M.order.length - 1, Math.max(0, M.order.indexOf(tier) + Number((M.sizeBump || {})[size] || 0)))
    tier = M.order[i]
  }
  const f = tier === s.tier ? s : (M.tiers || {})[tier] || s
  const out = {}
  if (f.model) out.model = f.model
  if (f.effort) out.effort = f.effort
  return out
}

const CAL = `Today is ${A.today}. Horizon: ${A.horizon}. Sprints (${A.sprintLength}):
${A.sprints.map(s => `- S${s.n} ${s.start} → ${s.end}${s.freeze ? ' — FREEZE: hotfix-class items only (fixes, compat, docs)' : ''}`).join('\n')}
- later: beyond the horizon.
Sizes for one developer: S ≤ 2 days (1.5), M ≤ 1 week (4), L > 1 week (8). Capacity: about ${CAPACITY} dev-days per sprint per plugin.${A.focus ? `\nTeam focus for this horizon: ${A.focus}.` : ''}
Prefer small, evidenced, shippable items over rewrites.`

const READONLY = `STRICTLY READ-ONLY: do not create, edit or delete files, switch branches, commit, install dependencies, run builds or comment on GitHub. Use read commands only (cat, ls, grep, git log/branch/show, gh issue/pr list/view, yayh roadmap list|status|links, yayh artifact list).`

const ITEM = {
  type: 'object',
  properties: {
    existing_id: { type: 'string', description: 'R-<n> when this is an item already in the plugin\'s docs/roadmap.md, else empty' },
    title: { type: 'string' },
    why: { type: 'string', description: 'one line on the customer value, with the evidence' },
    kind: { type: 'string', enum: ['feature', 'improvement', 'fix', 'compat', 'tech-debt', 'growth', 'integration'] },
    value: { type: 'string', enum: ['high', 'medium', 'low'] },
    size: { type: 'string', enum: ['S', 'M', 'L'] },
    editions: { type: 'string', description: 'e.g. "free, pro" or "pro"' },
    sprint: { type: 'string', enum: SPRINT_IDS },
    priority: { type: 'string', enum: ['must', 'should', 'could', 'cut'] },
    from: { type: 'string', description: 'BL-<n>, B-<n>, #issue or empty' },
    evidence: { type: 'array', items: { type: 'string' }, description: 'file paths, #issues, URLs' },
    depends: { type: 'array', items: { type: 'string' }, description: '"<plugin>:<item title or R-n>"' },
  },
  required: ['existing_id', 'title', 'why', 'kind', 'value', 'size', 'sprint', 'priority', 'evidence'],
}

const BRIEF = {
  type: 'object',
  properties: {
    plugin: { type: 'string' },
    state_summary: { type: 'string', description: '4-6 sentences: maturity, recent work, open work, health' },
    pain_points: { type: 'array', items: { type: 'object', properties: { text: { type: 'string' }, source: { type: 'string' } }, required: ['text', 'source'] } },
    items: { type: 'array', items: ITEM, description: 'existing unfinished roadmap items (keep their R ids) plus 5-12 new candidates' },
    integration_offers: { type: 'array', items: { type: 'object', properties: { what: { type: 'string' }, useful_for: { type: 'array', items: { type: 'string' } } }, required: ['what'] } },
    integration_asks: { type: 'array', items: { type: 'object', properties: { to_plugin: { type: 'string' }, ask: { type: 'string' }, why: { type: 'string' } }, required: ['to_plugin', 'ask', 'why'] } },
    sources: { type: 'array', items: { type: 'string' } },
  },
  required: ['plugin', 'state_summary', 'pain_points', 'items', 'integration_offers', 'integration_asks', 'sources'],
}

const COWORK = {
  type: 'object',
  properties: {
    plugin: { type: 'string' },
    answers: { type: 'array', items: { type: 'object', properties: { from_plugin: { type: 'string' }, ask: { type: 'string' }, decision: { type: 'string', enum: ['accept', 'defer', 'decline'] }, sprint: { type: 'string' }, note: { type: 'string' } }, required: ['from_plugin', 'ask', 'decision'] } },
    joint_initiatives: { type: 'array', items: { type: 'object', properties: { title: { type: 'string' }, plugins: { type: 'array', items: { type: 'string' } }, value_to_customer: { type: 'string' }, my_part: { type: 'string' } }, required: ['title', 'plugins', 'my_part'] } },
    conflicts: { type: 'array', items: { type: 'object', properties: { with_plugin: { type: 'string' }, issue: { type: 'string' }, recommendation: { type: 'string' } }, required: ['with_plugin', 'issue', 'recommendation'] } },
    items: { type: 'array', items: ITEM, description: 'FULL revised list for this plugin, including accepted integration items' },
  },
  required: ['plugin', 'answers', 'joint_initiatives', 'conflicts', 'items'],
}

const ROADMAP = {
  type: 'object',
  properties: {
    summary: { type: 'string', description: '3-5 sentences: the theme of this horizon across the portfolio' },
    shared_initiatives: { type: 'array', items: { type: 'object', properties: {
      title: { type: 'string' }, owner: { type: 'string' }, plugins: { type: 'array', items: { type: 'string' } },
      value_to_customer: { type: 'string' }, sprint: { type: 'string', enum: SPRINT_IDS },
      per_plugin_work: { type: 'array', items: { type: 'object', properties: { plugin: { type: 'string' }, work: { type: 'string' } }, required: ['plugin', 'work'] } },
    }, required: ['title', 'owner', 'plugins', 'sprint', 'per_plugin_work'] } },
    conventions: { type: 'array', items: { type: 'string' }, description: 'cross-plugin decisions (from conflicts)' },
    plugins: { type: 'array', items: { type: 'object', properties: {
      plugin: { type: 'string' },
      headline: { type: 'string' },
      sprint_goals: { type: 'array', items: { type: 'object', properties: { sprint: { type: 'string' }, goal: { type: 'string' } }, required: ['sprint', 'goal'] } },
      items: { type: 'array', items: ITEM },
      risks: { type: 'array', items: { type: 'string' } },
    }, required: ['plugin', 'headline', 'sprint_goals', 'items', 'risks'] } },
  },
  required: ['summary', 'shared_initiatives', 'conventions', 'plugins'],
}

const roster = PLUGINS.map(p => `- ${p.name} (${p.path}${p.repo ? `, GitHub ${p.repo}` : ''}, version ${p.version || '?'})`).join('\n')

phase('Research')
const briefs = (await parallel(PLUGINS.map(p => () => agent(
`You are the product owner and tech lead for the WordPress/WooCommerce plugin **${p.name}** by YayCommerce. Research it and return a roadmap brief. Later you'll co-plan with the owners of the other plugins:
${roster}

Repo: ${p.path}
${READONLY}

${CAL}

Research in this order:
1. The repo: CLAUDE.md, docs/knowledge/ (known-issues, decisions), docs/roadmap.md (existing items: keep every unfinished one with its R id in existing_id; skip shipped and dropped), docs/backlog/, open docs/bugs/ (by severity), docs/plans/ that are ready or in progress, readme.txt (features, Requires/Tested up to, recent changelog), \`git log --since=90.days --oneline\`, unmerged branches.${p.harnessed ? ' `yayh roadmap status` and `yayh roadmap links` summarize the docs (run them from the repo root).' : ''}
2. GitHub, if \`gh\` works${p.repo ? ` (-R ${p.repo})` : ''}: open issues and PRs.
${A.web ? `3. The web: the wordpress.org page (installs, rating, recent support threads, 1–3★ reviews), and 3–5 competitors (what they have that this plugin lacks).` : '3. Skip web research.'}

Return the unfinished existing items plus 5–12 new candidates with honest sizes, evidence and a suggested sprint that respects freezes. Also list integration offers (hooks, data or UI this plugin could give the others) and concrete asks of specific plugins in the roster.`,
  { label: `research:${p.name}`, phase: 'Research', schema: BRIEF, ...route('portfolio-research') }
)))).filter(Boolean)
log(`Research: ${briefs.length}/${PLUGINS.length} briefs`)
if (briefs.length < PLUGINS.length) log(`Missing briefs: ${PLUGINS.map(p => p.name).filter(n => !briefs.some(b => b.plugin === n)).join(', ')}`)

let rounds = []
if ((A.rounds || 2) >= 2) {
  phase('Co-work')
  const briefsJson = JSON.stringify(briefs)
  rounds = (await parallel(PLUGINS.map(p => () => agent(
`You are the owner of **${p.name}** (${p.path}). Every owner has written a research brief. Now co-plan.

${READONLY} You may re-open your repo to check whether an integration is feasible, and peek at the other repos to verify hooks they claim to offer.

${CAL}

ALL BRIEFS (JSON):
${briefsJson}

For ${p.name}:
1. Answer every integration ask addressed to ${p.name}: accept (with sprint), defer or decline, with a reason.
2. Propose joint initiatives with real customer value that fit the horizon.
3. Flag conflicts or overlaps with other plugins (duplicate features, competing discounts or widgets, inconsistent UX), with a recommendation.
4. Return the FULL revised item list for ${p.name}: own items plus accepted integration items, with sprint and priority. Keep existing_id on items that came from the roadmap. Freeze sprints hold hotfix-class items only.`,
    { label: `cowork:${p.name}`, phase: 'Co-work', schema: COWORK, ...route('cowork') }
  )))).filter(Boolean)
  log(`Co-work: ${rounds.length}/${PLUGINS.length} responses`)
} else {
  log('Co-work skipped (rounds=1)')
}

phase('Synthesis')
const roadmap = await agent(
`You are the portfolio product lead for the Yay plugins. Produce the final, consistent roadmap for this horizon.

${CAL}

RESEARCH BRIEFS:
${JSON.stringify(briefs)}

${rounds.length ? `CO-WORK OUTPUTS (answers, joint initiatives, conflicts, revised item lists):\n${JSON.stringify(rounds)}` : 'There was no co-work round: find the integrations yourself from the offers and asks.'}

Rules:
- Merge duplicate joint initiatives into one shared initiative with one owner and per-plugin work. Keep it only if every involved owner accepted or proposed it; otherwise move it to "later" and say so.
- Each plugin's items must match the shared initiatives: same sprint on both sides, or the dependency first.
- Capacity per plugin per sprint is about ${CAPACITY} dev-days (S=1.5, M=4, L=8). Freeze sprints hold hotfix-class items only. Move overflow to "later" or mark it cut.
- Turn conflicts into explicit conventions or plugin risks.
- Keep every existing_id, why and evidence. Include every plugin: ${PLUGINS.map(p => p.name).join(', ')}.`,
  { label: 'synthesis', phase: 'Synthesis', schema: ROADMAP, ...route('synthesis') }
)

return { briefs, rounds, roadmap }
