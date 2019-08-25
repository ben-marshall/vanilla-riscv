
# Branch Predictor

*Information on how the branch predictor of the core works.*

---

The branch predictor:

- Is a static predictor.

- Always predicts that a branch is taken.

- Only works on pc-relative control flow changes.

  - branch on compare, jump PC relative.

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

- Instead of the target address, `opr_c` is replaced with the natural
  *next* program counter of the instruction.

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