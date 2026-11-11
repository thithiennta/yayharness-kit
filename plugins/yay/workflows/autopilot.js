export const meta = {
  name: 'yay-autopilot',
  description: 'Take a queue of Yay roadmap items through brainstorm, plan and implement without stopping: prepare plans and collect the hard calls, or build every item on its own (stacked) branch',
  whenToUse: 'Called by /yay:autopilot with args built by the skill (mode prepare or build); not for direct use',
  phases: [
    { title: 'Prepare', detail: 'brainstorm and plan each item; return only the hard calls' },
    { title: 'Revise', detail: 'apply the decision-sheet answers to brainstorms and plans' },
    { title: 'Implement', detail: 'one item at a time, or --parallel=N; dependents stack on their dependency branch' },
    { title: 'Review', detail: 'yay:code-reviewer on each finished branch' },
    { title: 'Resolve', detail: 'fix or answer the review findings; push and open the PR (not with --no-pr)' },
  ],
}

// args (built by /yay:autopilot):
// { mode: 'prepare' | 'build', kit, repo, base, today, parallel, pr, draft,
//   items: [{ id, stage, artifact, after: [ids], waits: [ids], title }],
//   answers: { '<id>': '<what the user decided for this item, or empty>' } }   // build only
const A = args || {}
const KIT = A.kit
const ITEMS = A.items || []
const PAR = Math.max(1, Number(A.parallel) || 1)
const PR = A.pr !== false
if (!KIT || !A.repo) throw new Error('kit and repo are required')
if (!ITEMS.length) throw new Error('no items')

const CTX = `Repo: ${A.repo} (the main checkout). Base branch: ${A.base}. Today: ${A.today}.
The yay kit is at ${KIT}: wherever a skill says \${CLAUDE_PLUGIN_ROOT}, read ${KIT}. If \`yayh\` isn't on PATH, use ${KIT}/bin/yayh.
You are one step of /yay:autopilot, running unattended. NOBODY IS THERE TO ASK: never call AskUserQuestion. Follow ${KIT}/reference/asking.md as for a non-interactive run: take the recommended answer, write it under **Decided**, and never stop the work for an open point. Never push, tag or open a PR unless this prompt says to. Never use git add -A, --no-verify or --force.`

const QUESTION = {
  type: 'object',
  properties: {
    question: { type: 'string', description: 'one self-contained question naming the item, e.g. "R-3 Coupon UX: …?"' },
    why_hard: { type: 'string', description: 'why only the user can make it, or why it is expensive to undo' },
    options: { type: 'array', items: { type: 'object', properties: { label: { type: 'string' }, description: { type: 'string' } }, required: ['label', 'description'] }, description: '2-4 options, the recommended one first' },
    recommended: { type: 'string', description: 'label of the option the plan currently follows' },
  },
  required: ['question', 'why_hard', 'options', 'recommended'],
}

const PREPARED = {
  type: 'object',
  properties: {
    id: { type: 'string' },
    brainstorm: { type: 'string', description: 'BS-<n> or empty' },
    plan: { type: 'string', description: 'P-<n> or empty when blocked' },
    plan_status: { type: 'string', enum: ['draft', 'ready', 'none'] },
    option: { type: 'string', description: 'the brainstorm option the plan follows' },
    tasks: { type: 'number' },
    tests: { type: 'string', description: 'the plan\'s Tests line' },
    questions: { type: 'array', items: QUESTION, description: '0-2 hard calls; usually none' },
    decided: { type: 'array', items: { type: 'string' }, description: 'every other choice you made' },
    blocked: { type: 'string', description: 'empty, or why this item cannot be planned' },
  },
  required: ['id', 'brainstorm', 'plan', 'plan_status', 'option', 'questions', 'decided', 'blocked'],
}

const BUILT = {
  type: 'object',
  properties: {
    id: { type: 'string' },
    plan: { type: 'string' },
    branch: { type: 'string', description: 'empty when nothing was built' },
    worktree: { type: 'string' },
    commits: { type: 'array', items: { type: 'string' }, description: 'one line each: sha subject' },
    checks: { type: 'array', items: { type: 'string' }, description: 'each configured check with PASS/FAIL, pre-existing failures marked' },
    manual_checks: { type: 'array', items: { type: 'string' } },
    decided: { type: 'array', items: { type: 'string' } },
    status: { type: 'string', enum: ['done', 'blocked'] },
    blocked: { type: 'string', description: 'empty, or exactly what stopped it and what a human must do' },
  },
  required: ['id', 'plan', 'branch', 'worktree', 'commits', 'checks', 'decided', 'status', 'blocked'],
}

const RESOLVED = {
  type: 'object',
  properties: {
    fixed: { type: 'array', items: { type: 'string' } },
    answered: { type: 'array', items: { type: 'string' }, description: 'finding: your reason' },
    pr: { type: 'string', description: 'PR URL, or empty' },
    push_commands: { type: 'array', items: { type: 'string' }, description: 'exact push and gh pr create lines when no PR was opened' },
  },
  required: ['fixed', 'answered', 'pr', 'push_commands'],
}

// ---------- prepare ----------

function preparePrompt(it) {
  const start = {
    brainstorm: `There is no brainstorm yet. Follow ${KIT}/skills/brainstorm/SKILL.md with \`--from=${it.id}\` (no --decide, no --commit). Then plan its recommended option.`,
    decide: `${it.artifact} is an open brainstorm. Read it, and plan its recommended option (don't change the brainstorm's status: the decision sheet does that).`,
    plan: `${it.artifact} is a decided brainstorm. Plan its decision.`,
  }[it.stage]
  return `${CTX}

Bring roadmap item **${it.id} ${it.title}** to an implementable plan, in the main checkout. Create only new artifact files (\`yayh artifact new …\`); don't create branches, commit, or edit tracked files.${it.after.length ? `\nIt will be built after ${it.after.join(', ')} in this run, on top of their branches: plan it assuming their plans are done (read their brainstorms or plans under docs/ for what they add).` : ''}

1. ${start}
2. Follow ${KIT}/skills/plan/SKILL.md with \`--from=<the brainstorm id>\`, \`roadmap=${it.id}\`, the type that fits (feat unless it's a fix or refactor), and \`--tests=ask\`. Do every step, including the self-review and \`yayh plan check\` with no errors.
3. The plan skill's "Hard questions only" step is where you would ask. Don't ask. Instead:
   - Return as **questions** only the calls that are expensive to undo or that only the user can make: which brainstorm option (only when the options are genuinely close or change what customers see), customer-visible behaviour the source doesn't pin down, tests when the repo's rules say tests need approval. At most 2, usually 0. Each names the item and lists the option the plan follows first.
   - If a question is returned, leave the plan \`draft\` and write the question under the plan's ## Risks as "Open (autopilot sheet): …". Otherwise mark it ready (\`yayh fm set <plan> status ready\`).
   - Everything else you chose goes in **decided**.
4. If the item can't be planned (the evidence is missing, the code it names doesn't exist, it's really several items), set **blocked** with the reason and what a human must do, and create no plan.`
}

if (A.mode === 'prepare') {
  phase('Prepare')
  const todo = ITEMS.filter(it => ['brainstorm', 'decide', 'plan'].includes(it.stage))
  const skipped = ITEMS.filter(it => !todo.includes(it))
  if (skipped.length) log(`Already planned (no prepare needed): ${skipped.map(it => `${it.id} (${it.stage})`).join(', ')}`)
  const prepared = await runLimited(todo, PAR, it => agent(preparePrompt(it), { label: `prepare:${it.id}`, phase: 'Prepare', schema: PREPARED }))
  return { mode: 'prepare', prepared: prepared.map((p, i) => p || { id: todo[i].id, blocked: 'prepare agent failed', plan: '', plan_status: 'none', questions: [], decided: [] }) }
}

// ---------- build ----------

if (A.mode !== 'build') throw new Error(`unknown mode ${A.mode}`)
const ANSWERS = A.answers || {}

function revisePrompt(it, answer) {
  return `${CTX}

The user answered the autopilot decision sheet for **${it.id} ${it.title}** (plan ${it.artifact}):
${answer}

In the main checkout, apply it before anyone builds the plan:
- If it picks a brainstorm option, set the brainstorm's \`decision\` and \`status decided\` (\`yayh fm set\`), and write any condition into its Recommendation.
- Revise the plan (${KIT}/skills/plan/SKILL.md: Design, Tasks, Tests and Verify, Write it) so it follows the answer. Replace the "Open (autopilot sheet): …" risk lines with the decision. \`yayh plan check\` must have no errors. Then \`yayh fm set <plan> status ready\`.
- Edit only those untracked artifact files. Return a one-paragraph summary of what changed.`
}

function implementPrompt(it, baseBranch, mergeIn) {
  return `${CTX}

Build plan **${it.artifact}** (roadmap ${it.id} ${it.title}). Follow ${KIT}/skills/implement/SKILL.md with \`${it.artifact}${it.stage === 'continue' ? ' --continue' : ''} --base=${baseBranch} --no-push --no-review\`, with these changes for an unattended run:
- The "Hard questions only" round in Load and gate: don't ask. Decide in the plan's spirit and record it.${mergeIn.length ? `\n- After the Branch and worktree section creates the worktree, merge the other dependency branches into it: ${mergeIn.map(b => `\`git merge --no-ff --no-edit ${b}\``).join(', ')}. On a conflict, abort the merge and return blocked.` : ''}
- The task loop's "stop and tell the user" when the plan is wrong: if the fix to the task text is small and obviously in the plan's spirit, edit the plan's task text, note it under decided, and go on. Otherwise stop, leave the branch as it is (commit what works), and return blocked with the exact problem.
- Skip the "Review for reuse and comments" step of Finish (--no-review): the autopilot runs the reviewer next. Skip the "Push and PR" section (--no-push).
- A check that fails because of your change and that you can't fix in three attempts: return blocked. A pre-existing failure (also on ${A.base}) is reported, not fixed, and doesn't block.
Return the branch, worktree, commits, checks, manual checks left for a human, and every decision you made.`
}

function resolvePrompt(it, built, findings, prBase) {
  return `${CTX}

Branch \`${built.branch}\` (worktree ${built.worktree}) builds ${it.artifact} for ${it.id} ${it.title}. Work only in that worktree.

1. The yay:code-reviewer returned:
${findings}
   For each finding: fix it (call the existing helper, delete or restore the comment; commit \`refactor(<scope>): reuse <helper>\` or \`style(<scope>): restore comments\` with the \`Plan: ${it.artifact}\` trailer, then re-run the checks the change touches), or answer it with a reason. The review flags, it never blocks.
2. ${PR
    ? `Push and open the PR as in the "Push and PR" section of ${KIT}/skills/implement/SKILL.md: \`git push -u origin ${built.branch}\` and \`gh pr create --base ${prBase} --head ${built.branch} --assignee @me${A.draft ? ' --draft' : ''}\`. Fill the body from .github/pull_request_template.md. Under "Decided" list: ${JSON.stringify(built.decided)}. Under "Reuse and comments review", the fixed and answered findings.${prBase !== A.base ? ` Start the body with "Stacked on ${prBase}: merge that first."` : ''} Then \`yayh fm set <plan> pr <number>\`, commit and push.`
    : `Don't push. Return the exact commands instead: \`git push -u origin ${built.branch}\` and the \`gh pr create --base ${prBase} --head ${built.branch} --assignee @me …\` line.`}`
}

async function review(it, built, prBase) {
  const brief = `Worktree: ${built.worktree}. Base branch: ${prBase}. Plan: ${it.artifact}. Review this branch.`
  try {
    return await agent(brief, { label: `review:${it.id}`, phase: 'Review', agentType: 'yay:code-reviewer' })
  } catch (e) {
    return await agent(`${brief}\nYou are the reviewer defined in ${KIT}/agents/code-reviewer.md: read it and follow it exactly. Read-only.`, { label: `review:${it.id}`, phase: 'Review' })
  }
}

const results = {}
const done = {}       // id -> Promise<result>
const branchOf = {}   // id -> branch name
const slots = semaphore(PAR)

for (const it of ITEMS) {
  done[it.id] = (async () => {
    if (it.stage === 'done' || it.stage === 'dropped') return (results[it.id] = { id: it.id, status: 'skipped', blocked: `already ${it.stage}` })
    const deps = await Promise.all((it.after || []).map(d => done[d]))
    const failed = (it.after || []).filter((d, i) => !deps[i] || deps[i].status !== 'done')
    if (failed.length) return (results[it.id] = { id: it.id, status: 'skipped', blocked: `depends on ${failed.join(', ')}, which didn't finish` })
    if ((it.waits || []).length) return (results[it.id] = { id: it.id, status: 'skipped', blocked: `waits for ${it.waits.join(', ')} outside this run` })
    if (!it.artifact || !/^P-\d+$/.test(it.artifact)) return (results[it.id] = { id: it.id, status: 'skipped', blocked: 'no plan (prepare blocked it)' })

    const release = await slots()
    try {
      const answer = ANSWERS[it.id]
      if (answer) await agent(revisePrompt(it, answer), { label: `revise:${it.id}`, phase: 'Revise' })

      const depBranches = (it.after || []).map(d => branchOf[d]).filter(Boolean)
      const baseBranch = depBranches[0] || A.base
      const built = await agent(implementPrompt(it, baseBranch, depBranches.slice(1)), { label: `implement:${it.id}`, phase: 'Implement', schema: BUILT })
      if (!built) return (results[it.id] = { id: it.id, status: 'blocked', blocked: 'implement agent failed' })
      if (built.branch) branchOf[it.id] = built.branch
      if (built.status !== 'done') return (results[it.id] = { ...built, base: baseBranch })

      const findings = await review(it, built, baseBranch)
      const resolved = await agent(resolvePrompt(it, built, findings || '(the reviewer returned nothing)', baseBranch), { label: `resolve:${it.id}`, phase: 'Resolve', schema: RESOLVED })
      return (results[it.id] = { ...built, base: baseBranch, review: resolved })
    } finally {
      release()
    }
  })()
}
await Promise.all(Object.values(done))
const order = ITEMS.map(it => results[it.id])
log(`Built ${order.filter(r => r.status === 'done').length}/${ITEMS.length}; blocked ${order.filter(r => r.status === 'blocked').length}; skipped ${order.filter(r => r.status === 'skipped').length}`)
return { mode: 'build', results: order }

// ---------- helpers ----------

function semaphore(n) {
  let free = n
  const waiting = []
  return () => new Promise(resolve => {
    const grant = () => { free--; resolve(() => { free++; if (waiting.length) waiting.shift()() }) }
    if (free > 0) grant(); else waiting.push(grant)
  })
}

async function runLimited(list, n, fn) {
  const take = semaphore(n)
  return Promise.all(list.map(async x => {
    const release = await take()
    try { return await fn(x) } catch (e) { return null } finally { release() }
  }))
}
