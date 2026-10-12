---
name: article-polish
description: Review articles for readability, clarity, narrative flow, repetition, unnatural phrasing, and reader friction, including screenshots, charts, captions, and labels. Use for requests to polish an article, review a draft for readability, improve article prose, or check writing before publication across genres. Preserve the author's voice, factual accuracy, and intended audience; review without rewriting by default.
---

# Article polish

This is an experimental Agent Scripts skill.

Follow project instructions before this skill. Default to review only: do not
modify files unless explicitly requested. Interpret requests as follows:

- "Review this article for readability" means report findings without editing.
- "Polish this article" or "Revise this article" explicitly requests targeted
  improvements; apply edits rather than automatically rewriting the whole article.

An explicit review-only or no-edit constraint takes precedence.

## Read as the intended reader

Read the entire article before reporting findings. Establish its audience,
genre, purpose, and tone from the request and draft; ask only when uncertainty
materially affects the review. Adapt recommendations to that context, including
what the audience already knows.

Look for meaningful reader friction:

- Repeated words, phrases, explanations, sections, or conclusions. Distinguish
  useful emphasis and reminders from repetition that adds nothing.
- Unnecessary hedging, verbose constructions, stiff or formulaic language,
  awkward transitions, and sentences whose complexity obscures the point.
- Overexplaining familiar concepts, paragraphs that interrupt the narrative,
  information introduced too early, missing context, and unclear connections.
- Claims whose wording leaves readers unsure whether they are facts,
  approximations, or illustrative examples.

## Inspect visuals in context

Inspect actual screenshots, charts, and other visual assets when available,
alongside their headings, captions, alt text, and surrounding prose. Use an
available image viewer or rendered document; filenames and markup alone do not
verify visual content. Identify inaccessible assets and their visual checks as
unverified, while still reviewing the available text.

Check whether each visual teaches something useful and whether nearby text or
other visuals repeat it unnecessarily. Captions should supply useful context
rather than merely repeat a heading. Alt text should convey essential visual
information; overlap with a caption can be necessary for accessibility, so do
not remove it solely to avoid repetition.

Look for confusing legends, units, labels, or terminology; inconsistencies
between visual evidence and prose; unreadable details; and unnecessary clutter.
Check that hypothetical or illustrative visuals and approximate measurements
are identified clearly. Flag ambiguity without inventing provenance, exact
values, evidence, sources, or conclusions.

## Keep intervention minimal

Leave good writing alone. Preserve the author's voice, tone, factual accuracy,
technical precision, and necessary qualifications. Do not impose arbitrary
rules about contractions, em dashes, passive voice, or sentence length, or
rewrite merely to make prose appear less AI-generated. Avoid nitpicking.

Keep this review focused on the reading experience. SEO, marketing strategy,
calls to action, publication metadata, mandatory disclosures, and project-specific
writing or publishing requirements are outside this skill's scope. Existing
promotional text can be reviewed for readability and flow; do not require or
introduce promotional content.

## Report or edit

Report concise, actionable findings with locations (section, paragraph, line,
or figure), the reader impact, and a brief recommendation. Group related issues
instead of listing every occurrence. Separate meaningful problems from optional
stylistic suggestions; use short before/after examples only when they clarify
the recommendation. State any unverified visual checks. If the article reads
well, say so without inventing findings.

For an explicitly requested revision, make only supported, targeted edits and
briefly summarize them and any unresolved questions. Preserve uncertain facts
and qualifications; flag matters requiring author confirmation instead of
silently resolving them.
