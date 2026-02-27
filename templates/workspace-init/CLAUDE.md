# Research Workspace

## Documentation System

You have a `knowledge-tracer` subagent for ALL documentation in `knowledge/`. **Do not write `knowledge/` files yourself** — delegate to it using the Task tool. The knowledge-tracer understands the existing narrative, maintains wikilinks across documents, creates Mermaid diagrams, and keeps everything consistent.

### When to Delegate

| Event | What to pass to knowledge-tracer |
|-------|----------------------------------|
| **Read a paper** | Paper ID, title, your summary, key findings, relevance to our research, decision (use/discard/reference-only) |
| **Made a decision** | What was decided, context, options considered, what you chose and why |
| **Ran an experiment** | What you tested, hypothesis, setup, results, interpretation, issues |
| **Hit an error** | What happened, what phase, how you resolved it |
| **End of phase** | Ask it to write/update the narrative README.md synthesizing everything |
| **New info changes old conclusions** | Tell it what changed and which existing notes need updating |

### How to Delegate

Use the Task tool to spawn the `knowledge-tracer` agent. Be specific about what happened and why it matters — the more context you give, the better the documentation.

Good: "Document paper 2407.14192 (LeKUBE). It's a legal knowledge update benchmark testing LLMs on EU legislation changes — amendments, repeals, new provisions. Key finding: LLMs get ~30-40% accuracy on post-update law questions even with RAG. Their dataset of 1,200 QA pairs from EU Official Journal could be our primary evaluation set. This directly validates our hypothesis that temporal coherence is an unsolved problem. High relevance, decision: USE."

Bad: "Document paper 2407.14192."

### Important Rules

1. **Delegate IMMEDIATELY** — after each paper, each decision, each error. Don't batch them.
2. **Keep working** — delegation is fire-and-forget. The knowledge-tracer handles the documentation while you continue.
3. **At the end of your phase**, delegate one final time asking the knowledge-tracer to write the full narrative README.md with Mermaid diagrams.
4. **Read `knowledge/README.md`** at the start of your phase to understand the story so far.

### Knowledge Inventory
(updated by knowledge-tracer after each action)

Papers: (none yet)
Decisions: (none yet)
Experiments: (none yet)
Errors: (none yet)
