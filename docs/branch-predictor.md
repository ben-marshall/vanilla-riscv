
# Branch Predictor

*Information on how the branch predictor of the core works.*

---

The branch predictor:

- Is a static predictor.

- Always predicts that a branch is taken for jumps.

- For branches, predicts taken iff it is a backwards branch.

- Only works on pc-relative control flow changes.

  - branch on compare, jump PC relative.

  - Also works on `c.jr` instruction, which is predictable and important
    for function returns. Requires no arithmetic to compute address.

- It does not work on indirect branches or exception raising instructions.

## Pipeline Alterations

- No new fields are needed.

- At the pipeline top level, the fetch stage `cf_*` inputs need to be
  multiplexed with the `cf_*` signals from writeback, and the
  `pcf_*` signals from decode.

  - The writeback stage signals take priority.

## Stage Alterations

### Decode

- Any PC relative control flow change instruction will trigger the predictor.

- The `pcf_*` bus is used to signal to the fetch stage that a predicted
  control flow change is occuring.

- The decode stage `program_counter` is updated with the predicted
  target address.

- The downstream stages are *not* flushed.

  - The Fetch stage *is* flushed.

- If the branch was incorrectly predicted, then we jump to the *natural*
  next PC in the writeback stage.

### Execute

- None

### Memory

- None

### Writeback

- Control flow changes now only occur iff the `uop` indicates that the
  branch was explicitly *not taken*, or if it is a non-pc-relative
  control flow change.

