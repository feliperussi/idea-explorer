---
name: knowledge-trace
description: Write Obsidian-compatible knowledge notes that tell the story of your research — what you found, what you decided, what you tested, and what it means. The output should read like a blog post, not a spreadsheet.
---

# Knowledge Trace Skill

Write Obsidian-compatible notes that tell the story of your research process. A human should be able to open `.knowledge/README.md` in Obsidian and understand everything — the question, the literature, the experiments, the findings — by reading one continuous narrative with links to deeper details.

## Core Principle

**Write prose, not catalogs.** The main document (README.md) is a blog post that tells the story. Detailed notes (papers, experiments, decisions) are linked from the story for readers who want to go deeper.

## When to Use

- After reading each paper → write a paper note
- After each experiment → write an experiment note
- When making a significant decision → write a decision note
- When encountering an error → append to errors.md
- At the end of each phase → update README.md with the narrative

## Output Directory

```
.knowledge/
  README.md              ← THE STORY (main narrative — start here)
  errors.md              ← Structured error log
  papers/
    {arxiv-id}.md        ← One note per paper (linked from the story)
  experiments/
    {number}-{slug}.md   ← One note per experiment (linked from the story)
  decisions/
    {number}-{slug}.md   ← One note per significant decision (linked from the story)
```

## Obsidian Conventions

Every `.md` file in `.knowledge/` MUST follow these rules:

1. **YAML frontmatter** at the top (between `---` delimiters)
2. **Wikilinks** for cross-references: `[[papers/2401.12345]]` or `[[papers/2401.12345|display text]]`
3. **Tags** in frontmatter (not inline): `tags: [paper, relevant]`
4. **Callouts** for important notes: `> [!warning]`, `> [!tip]`, `> [!note]`
5. **Collapsible callouts** for secondary info: `> [!note]- Title` (collapsed by default)

See `references/obsidian-markdown.md` for full syntax reference.

## README.md — The Main Narrative

This is the most important file. Written as continuous prose, it tells the full research story. Structure:

### Resource Finder writes:
- **The Question**: What we're investigating and why
- **What We Found in the Literature**: Narrative of papers grouped by themes
- **What We Decided**: Key decisions explained in context
- **What's Next**: Handoff to the experiment runner

### Experiment Runner appends:
- **The Experiments**: Narrative of what was tested, in sequence
- **Key Findings**: Synthesis of all results into a coherent answer
- **What Didn't Work**: Honest account of errors and limitations
- **Conclusion**: Was the hypothesis validated?

### Paper Writer reads:
- Uses README.md as the backbone for structuring the paper

## Integration with Pipeline Phases

### During Resource Finder
1. Create `.knowledge/` directory at the start
2. After reading each paper → write `.knowledge/papers/{id}.md`
3. When choosing datasets/repos → write `.knowledge/decisions/{n}-{slug}.md`
4. On errors → append to `.knowledge/errors.md`
5. At the end → write `.knowledge/README.md` with the narrative

### During Experiment Runner
1. Read `.knowledge/README.md` to understand the story so far
2. After each experiment → write `.knowledge/experiments/{n}-{slug}.md`
3. When pivoting approach → write `.knowledge/decisions/{n}-{slug}.md`
4. On errors → append to `.knowledge/errors.md`
5. At the end → append experiment narrative to `.knowledge/README.md`

### During Paper Writer
1. Read `.knowledge/README.md` for the full research story
2. Use the narrative to structure the paper
3. Cross-reference paper notes for Related Work
4. Cross-reference experiment notes for Results
