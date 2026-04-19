# Visual Companion

Use this only after the user has accepted the browser-based companion offer.

## Purpose

The visual companion is for moments when the user will understand something better by seeing it than by reading it.

Use it for:

- mockups
- wireframes
- layout comparisons
- architecture or flow diagrams
- side-by-side visual alternatives

Do not use it for:

- requirements questions
- scope decisions
- text-only tradeoffs
- conceptual clarifications that do not benefit from a visual

## Offer Text

The consent message must be sent by itself with no extra content:

`Some of what we're working on might be easier to explain if I can show it to you in a web browser. I can put together mockups, diagrams, comparisons, and other visuals as we go. This feature is still new and can be token-intensive. Want to try it? (Requires opening a local URL)`

## Per-Question Rule

Even after the user accepts, decide question by question whether the browser adds value.

Use the browser when the answer is primarily visual.
Use normal chat when the answer is primarily textual.

Examples:

- "Which dashboard layout feels cleaner?" -> visual
- "What does personality mean in this interface?" -> text
- "Which navigation model is easier to learn?" -> usually text first, visual only if comparing concrete layouts

## Constraints

- Do not route every question through the browser.
- Do not combine the visual companion offer with clarifying questions or status updates.
- If the browser is unavailable or would add friction, continue in text rather than blocking progress.
