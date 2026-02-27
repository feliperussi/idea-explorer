# Research Workspace

## Documentation System

You have a `knowledge-tracer` subagent that maintains `knowledge/` as a **guide layer** connecting all your research outputs. It does NOT replace your deliverables (literature_review.md, resources.md, planning.md, REPORT.md) — it connects them into a coherent story.

**Do not write `knowledge/` files yourself** — delegate to the knowledge-tracer using the Task tool.

### When to Delegate

| Event | What to pass to knowledge-tracer |
|-------|----------------------------------|
| **Read a paper** (even if discarded) | Paper ID, title, your summary, key findings, relevance, decision (use/discard/reference-only). For discards, a brief reason is fine. |
| **Made a decision** | What was decided, context, options considered, what you chose and why. Must be a SEPARATE decision note, not just inline. |
| **Ran an experiment** | What you tested, hypothesis, setup, results, interpretation, issues |
| **Hit an error** | What happened, what phase, how you resolved it |
| **End of phase** | Ask it to write/update knowledge/guide.md — the concise storyline linking to all deliverables |
| **New info changes old conclusions** | Tell it what changed and which existing notes need updating |

### How to Delegate

Use the Task tool to spawn the `knowledge-tracer` agent. Be specific — the more context you give, the richer the documentation.

Good: "Document paper 2407.14192 (LeKUBE). It's a legal knowledge update benchmark testing LLMs on EU legislation changes — amendments, repeals, new provisions. Key finding: LLMs get ~30-40% accuracy on post-update law questions even with RAG. High relevance, decision: USE."

Bad: "Document paper 2407.14192."

### Important Rules

1. **Delegate IMMEDIATELY** — after each paper (even discarded ones), each decision, each error.
2. **Keep working** — delegation is fire-and-forget.
3. **Your deliverables should use Obsidian format** — add YAML frontmatter and [[wikilinks]] to knowledge/ notes in literature_review.md, resources.md, etc.
4. **At the end of your phase**, delegate one final time asking the knowledge-tracer to write knowledge/guide.md — concise, with Mermaid diagrams, linking to deliverables.
5. **Read `knowledge/guide.md`** at the start of your phase to understand the story so far.

### Knowledge Inventory
(updated by knowledge-tracer after each action)

Papers: (none yet)
Decisions: (none yet)
Experiments: (none yet)
Errors: (none yet)
