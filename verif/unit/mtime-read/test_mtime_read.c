
#include "unit_test.h"

/*!
@brief Test reading of the standard performance counters/timers.
@note Assumes that all counters are reset to zero and do not roll over during
the test.
*/
int test_main() {

    uint64_t fst_mtime      = __rd_mtime();
    uint64_t fst_mtimecmp   = __rd_mtimecmp();

    uint64_t snd_mtime      = __rd_mtime();
    uint64_t snd_mtimecmp   = __rd_mtimecmp();

    if(fst_mtime > snd_mtime) {
        // Second reading of mtime should be a larger value.
        return 1;
    }
    
    if(fst_mtimecmp != snd_mtimecmp) {
        // mtimecmp should not have changed
        return 2;
    }
    
    if(*__mtimecmp != __rd_mtimecmp()) {
        // Shouldn't matter how we access mtimecmp
        return 2;
    }


    return 0;

}
