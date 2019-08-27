
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

  - The Fetch stage *is* flushed.

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

---

~~Todo: Fix writeback stage PC tracking.~~

- Transmit branch target address down the pipeline from decode in
  `opr_c` as it used to be.

- If we get to writeback and find an incorrectly predicted branch, just
  the writeback stage `s4_n_pc` as the target address for the "correcting"
  jump.

- Add a selection to the `s4_pc` update process, where any *correctly*
  predicted branch causes it's value to be set to the branch target
  address transmitted down from the decode stage.

~~Todo: Fix jump register instructions~~

- They need to source their target addresses from `s4_opr_ra` but currently
  do not.

~~Todo: Fix RVFI tracing~~

- Because we have effectively inverted when a conditional branch is
  *taken*, the `pcwdata` field for RVFI will report the branch target
  when it should report the next instruction, and vice versa.

~~Todo: Flexibility in the predictor~~

- Be able to predict taken or not taken, and resolve this in the
  writeback stage.

~~Todo: Fix simulation data memory response~~

- Data memory responses always take two cycles due to sim sync issues!
