
# Performance

*Somewhere to keep track of performance over time.*

---

## Baseline

- No Branch Prediction
  - 4 cycle control flow change penalty.
- No Stalling
- Instruction prefetch depth: 3
- 2 cycle memory latency. Due to bug in testbench.

## Improvement 1: Testbench bug fixed and trivial branching.

- No Branch Prediction
  - 4 cycle conditional control flow change penalty.
  - 1 cycle PC relative jump penalty.
- No Stalling
- Instruction prefetch depth: 3
- 1 cycle memory latency.

## Improvement 2: Simple "If backwards, predict taken"

- Static Branch Prediction
  - 4 cycle conditional control flow change penalty.
  - Always predict taken if the branch is backwards.
    - 1 cycle penalty for correct prediction
    - 4 cycle penalty for incorrect prediction
  - 1 cycle PC relative jump penalty.
- No Stalling
- Instruction prefetch depth: 3
- 1 cycle memory latency.

## Improvement 3: Faster function return.

- Static Branch Prediction
  - 4 cycle conditional control flow change penalty.
  - Always predict taken if the branch is backwards.
    - 1 cycle penalty for correct prediction
    - 4 cycle penalty for incorrect prediction
  - 1 cycle PC relative jump penalty.
- `c.jr` now takes it's control flow change in decode, not
  writeback.
  - Results in much faster returns from functions.
- No Stalling
- Instruction prefetch depth: 3
- 1 cycle memory latency.

## Improvement 4: Better Prefetching

- Static Branch Prediction
  - 4 cycle conditional control flow change penalty.
  - Always predict taken if the branch is backwards.
    - 1 cycle penalty for correct prediction
    - 4 cycle penalty for incorrect prediction
  - 1 cycle PC relative jump penalty.
- `c.jr` now takes it's control flow change in decode, not
  writeback.
  - Results in much faster returns from functions.
- The prefetcher no longer stops working while the outstanding
  requests in the shadow of a taken branch drain.
- No Stalling
- Instruction prefetch depth: 3
- 1 cycle memory latency.
