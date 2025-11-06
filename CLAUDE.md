# SpaceNote PostgreSQL Project Instructions

## Context

This is an experimental fork of SpaceNote testing PostgreSQL as an alternative to MongoDB. Before making any changes or suggestions, **you MUST read and understand the README.md file** to understand:

- The project's goals and hypothesis
- The problems with the MongoDB implementation we're trying to solve
- The three key issues: dual identity system, opaque field references, and lack of referential integrity
- How PostgreSQL is expected to address these issues

## Key Requirements

1. **Always read README.md first** - The README contains critical context about why this experiment exists and what problems we're solving
2. Maintain awareness of the original MongoDB implementation at [spacenote-backend](https://github.com/spacenote-projects/spacenote-backend)
3. Focus on PostgreSQL's strengths: referential integrity, human-readable identifiers, and transparent data relationships
