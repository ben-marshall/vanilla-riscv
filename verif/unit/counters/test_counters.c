
#include "unit_test.h"

/*!
@brief Test reading of the standard performance counters/timers.
@note Assumes that all counters are reset to zero and do not roll over during
the test.
*/
int test_main() {

    // The counters are enabled
    uint32_t enabled = __rdmcountinhibit();
    
    if((enabled&0x7) != 0x0) {
        __wrmcountinhibit(0x0);
    }


    uint64_t a_cycle      = __rdcycle();
    uint64_t a_time       = __rdtime();
    uint64_t a_instret    = __rdinstret();

    uint64_t b_cycle      = __rdcycle();
    uint64_t b_time       = __rdtime();
    uint64_t b_instret    = __rdinstret();


    if(a_cycle >= b_cycle) {
        // Second reading of cycle should be larger
        return 1;
    }

    if(a_time >= b_time) {
        // Second reading of time should be larger
        return 2;
    }

    if(a_instret >= b_instret) {
        // Second reading of instret should be larger.
        return 3;
    }

    // Disable the cycle counter register
    __wrmcountinhibit(0x1);
    
    
    a_cycle      = __rdcycle();
    a_time       = __rdtime();
    a_instret    = __rdinstret();

    b_cycle      = __rdcycle();
    b_time       = __rdtime();
    b_instret    = __rdinstret();


    if(a_cycle != b_cycle) {
        // Cycle disabled, should be identical.
        return 4;
    }

    if(a_time >= b_time) {
        // Second reading of time should be larger
        return 5;
    }

    if(a_instret >= b_instret) {
        // Second reading of instret should be larger.
        return 6;
    }
    
    // Disable the time counter register, re-enable the cycle register.
    __wrmcountinhibit(0x2);
    
    a_cycle      = __rdcycle();
    a_time       = __rdtime();
    a_instret    = __rdinstret();

    b_cycle      = __rdcycle();
    b_time       = __rdtime();
    b_instret    = __rdinstret();

    if(a_cycle >= b_cycle) {
        // Cycle enabled, first reading should be smaller.
        return 7;
    }

    if(a_time != b_time) {
        // time register disabled. Should stay the same.
        return 8;
    }

    if(a_instret >= b_instret) {
        // Second reading of instret should be larger.
        return 9;
    }
    
    // Disable the instr ret register, re-enable the time register.
    __wrmcountinhibit(0x4);
    
    a_cycle      = __rdcycle();
    a_time       = __rdtime();
    a_instret    = __rdinstret();

    b_cycle      = __rdcycle();
    b_time       = __rdtime();
    b_instret    = __rdinstret();

    if(a_cycle >= b_cycle) {
        // Cycle enabled, first reading should be smaller.
        return 10;
    }

    if(a_time >= b_time) {
        // time register enabled . first reading should be smaller.
        return 11;
    }

    if(a_instret != b_instret) {
        // instrret disabled, should not change.
        return 12;
    }
    
    __wrmcountinhibit(0x0);

    return 0;

}
