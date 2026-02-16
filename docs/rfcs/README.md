# RFC Process

> RFC process version: **v1.0.0**

Use RFCs for significant changes, including:

- Breaking API changes
- Architectural boundary changes
- Governance or contribution policy changes
- Major dependency or platform shifts

## How to submit an RFC

1. Copy the RFC template:

```bash
cp docs/rfcs/0000-template.md docs/rfcs/0001-short-title.md
```

2. Fill in all required sections.
3. Open a PR including the RFC file.
4. Link PR to an RFC issue (`RFC Proposal` issue template).

## RFC lifecycle

- `Draft` -> under discussion
- `Proposed` -> ready for maintainer decision
- `Accepted` -> approved for implementation
- `Implemented` -> shipped
- `Rejected` -> not accepted (with reasons)

## Decision rules

- One maintainer approval for non-breaking RFCs.
- One core maintainer approval for breaking/governance RFCs.

## Repository conventions

- RFC filenames: `NNNN-short-title.md`
- Keep RFCs immutable after accepted, except status and editorial fixes.
