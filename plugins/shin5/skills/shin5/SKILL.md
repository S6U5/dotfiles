---
name: shin5
description: Explain any topic in very simple Japanese, diagram-first. When the chat is running in a Chrome extension side panel, also use it whenever the user asks to have something explained or indicates they do not understand it (for example "解説して" or "わからない" — examples only, not an exhaustive list). Anywhere else, use it only when the user explicitly invokes "$shin5" or says "shin5".
---

# shin5

## When to use this skill

If this chat is running from a Chrome extension side panel, use this skill automatically whenever the user asks to have something explained, or indicates they do not understand it. "解説して" / "説明して" / "わからない" / "よくわからない" are examples, not an exhaustive list — treat any request for an explanation the same way.

Anywhere else, use this skill only when the user explicitly invokes `$shin5` or says "shin5".

## How to explain

Explain like I'm someone who knows nothing about this topic, in Japanese, using a diagram-first explanation with big pictures and few words.

Use SVG for intuitive concept illustrations, visual metaphors, and spatial explanations. Keep each SVG diagram-first, using shapes, arrows, and only essential labels. Put explanatory prose, reasoning, and option-by-option notes outside the SVG code blocks.

Use Mermaid for relationships that are clearer as a formal diagram: structures, connections, processes, sequences, state changes, comparisons, and hierarchies. Choose the Mermaid diagram type that fits the relationship (flowchart, swimlane, sequence, class, state, ER, user journey, Gantt, pie, XY, radar, quadrant, requirement, Gitgraph, C4, mindmap, timeline, ZenUML, Sankey, block, packet, Kanban, architecture, event modeling, treemap, Venn, Ishikawa, Wardley, Cynefin, or tree view). Do not use Mermaid merely to turn prose into boxes.

For architecture diagrams, show ownership, placement, and boundaries with groups or nested containers so it is clear where each component belongs (for example, an organization, environment, network, or system). Do not use a single horizontal row for an architecture diagram; reserve it for timelines or data flows.

Before using an unfamiliar technical term in a diagram, introduce it briefly in plain Japanese. If introducing it first would interrupt the flow, define it immediately after the diagram instead.

When a closely related concept could be confused with the topic, explain the difference clearly. Use a second image only when it helps the comparison.

For multiple-choice questions, explain why the correct choice is correct and why each incorrect choice is wrong. Briefly state when an incorrect choice would be correct, when applicable.

## Where to put the diagrams

Where `svg` and `mermaid` code blocks are rendered as pictures (for example a Chrome extension side panel), output SVG in `svg` code blocks and Mermaid in `mermaid` code blocks. Split diagrams when that makes the explanation clearer.

Where they are not rendered (for example a terminal), put the diagrams in an HTML artifact instead, keeping the same big-pictures-few-words approach.

Topic: $ARGUMENTS
