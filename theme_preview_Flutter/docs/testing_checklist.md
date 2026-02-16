# Testing Checklist

## Product Parity

- [ ] Core repo → PR → detail flow works under all role simulations.
- [ ] AI review simulation supports queued/running/completed/failed states.
- [ ] Merge operations persist and reflect in subsequent screen visits.

## Theme & UX Adaptation

- [ ] Light/dark parity for all canonical screens.
- [ ] Compact/comfortable density preserves readability.
- [ ] Focus/review modes alter emphasis as designed.
- [ ] Theme variants A/B/C apply consistently across components.

## Governance and Safety

- [ ] Demo mode watermark always visible when runtime mode is demo.
- [ ] Role-restricted screens are hidden outside authorized roles.
- [ ] Diff detector reports no missing screens or empty action bindings.

## Performance Simulation

- [ ] High-density workflow simulation remains responsive.
- [ ] Context panel rendering does not block primary content.
