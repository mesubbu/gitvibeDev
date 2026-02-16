# Maintainer Guidelines

> Maintainer guide version: **v1.0.0**

## Maintainer responsibilities

- Keep issues and PR queues responsive.
- Maintain release hygiene (`VERSION`, `CHANGELOG.md`, release tag).
- Enforce security and disclosure policy.
- Keep public roadmap and RFC decisions traceable.

## Weekly operations checklist

```text
[ ] Triage new issues
[ ] Review pending PRs
[ ] Label PRs for release drafting categories
[ ] Check open RFC status
[ ] Confirm CI and release workflow health
```

## Merge policy

- At least one maintainer review for normal changes.
- At least one core maintainer review for architecture/governance changes.
- Require passing CI and semver check.

## Release policy

- Patch: bugfixes, security fixes, docs corrections.
- Minor: backward-compatible features.
- Major: breaking changes (requires RFC + migration notes).

Release checklist:

```bash
# 1) Ensure VERSION and CHANGELOG are ready
cat VERSION
sed -n '1,120p' CHANGELOG.md

# 2) Tag and push
git tag v$(cat VERSION)
git push origin v$(cat VERSION)
```

## Community behavior expectations

- Assume good intent.
- Keep review feedback specific and actionable.
- Prefer public design discussion for non-sensitive decisions.
