
#include <assert.h>

#include "dut_wrapper.hpp"

/*!
*/
dut_wrapper::dut_wrapper (
    memory_bus    * mem         ,
    bool            dump_waves  ,
    std::string     wavefile
){


    this -> dut                    = new Vfrv_core();

    this -> dump_waves             = dump_waves;
    this -> vcd_wavefile_path      = wavefile;
    this -> mem                    = mem;

    this -> imem_agent               = new sram_agent(mem);
    this -> imem_agent -> mem_req   = &this -> dut -> imem_req  ;
    this -> imem_agent -> mem_gnt   = &this -> dut -> imem_gnt  ;
    this -> imem_agent -> mem_recv  = &this -> dut -> imem_recv ;
    this -> imem_agent -> mem_ack   = &this -> dut -> imem_ack  ;
    this -> imem_agent -> mem_wen   = &this -> dut -> imem_wen  ;
    this -> imem_agent -> mem_error = &this -> dut -> imem_error;
    this -> imem_agent -> mem_strb  = &this -> dut -> imem_strb ;
    this -> imem_agent -> mem_addr  = &this -> dut -> imem_addr ;
    this -> imem_agent -> mem_rdata = &this -> dut -> imem_rdata;
    this -> imem_agent -> mem_wdata = &this -> dut -> imem_wdata;
    
    this -> dmem_agent              = new sram_agent(mem);
    this -> dmem_agent -> mem_req   = &this -> dut -> dmem_req  ;
    this -> dmem_agent -> mem_gnt   = &this -> dut -> dmem_gnt  ;
    this -> dmem_agent -> mem_recv  = &this -> dut -> dmem_recv ;
    this -> dmem_agent -> mem_ack   = &this -> dut -> dmem_ack  ;
    this -> dmem_agent -> mem_wen   = &this -> dut -> dmem_wen  ;
    this -> dmem_agent -> mem_error = &this -> dut -> dmem_error;
    this -> dmem_agent -> mem_strb  = &this -> dut -> dmem_strb ;
    this -> dmem_agent -> mem_addr  = &this -> dut -> dmem_addr ;
    this -> dmem_agent -> mem_rdata = &this -> dut -> dmem_rdata;
    this -> dmem_agent -> mem_wdata = &this -> dut -> dmem_wdata;

    Verilated::traceEverOn(this -> dump_waves);

    if(this -> dump_waves){
        this -> trace_fh = new VerilatedVcdC;
        this -> dut -> trace(this -> trace_fh, 99);
        this -> trace_fh -> open(this ->vcd_wavefile_path.c_str());
    }

    this -> sim_time               = 0;

}
    
//! Put the dut in reset.
void dut_wrapper::dut_set_reset() {

    // Put model in reset.
    this -> dut -> g_resetn     = 0;
    this -> dut -> g_clk        = 0;

    this -> imem_agent -> set_reset();
    this -> dmem_agent -> set_reset();

}
    
//! Take the DUT out of reset.
void dut_wrapper::dut_clear_reset() {
    
    this -> dut -> g_resetn = 1;
    
    this -> imem_agent -> clear_reset();
    this -> dmem_agent -> clear_reset();

}


//! Simulate the DUT for a single clock cycle
void dut_wrapper::dut_step_clk() {

    vluint8_t prev_clk;

    for(uint32_t i = 0; i < this -> evals_per_clock; i++) {

        prev_clk = this -> dut -> g_clk;
        
        if(i == this -> evals_per_clock / 2) {
            
            this -> dut -> g_clk = !this -> dut -> g_clk;
            
            if(this -> dut -> g_clk == 1){

                this -> posedge_gclk();
            }
       
        } 
        
        this -> dut      -> eval();
        
        // Drive interface agents
        this -> imem_agent -> drive_signals();
        this -> dmem_agent -> drive_signals();

        this -> dut -> eval();

        this -> sim_time ++;

        if(this -> dump_waves) {
            this -> trace_fh -> dump(this -> sim_time);
        }

    }

}


void dut_wrapper::posedge_gclk () {

    this -> dmem_agent -> posedge_clk();
    this -> imem_agent -> posedge_clk();

    // Do we need to capture a trace item?
    if(this -> dut -> trs_valid) {
        this -> dut_trace.push (
            {
                this -> dut -> trs_pc,
                this -> dut -> trs_instr
            }
        );
    }
}


bool dut_wrapper::rand_chance(int x, int y) {
    return (rand() % y) < x;
}


bool dut_wrapper::rand_set_uint8(int x, int y, vluint8_t * d) {
    if(rand_chance(x,y)) {
        *d = 1;
        return true;
    } else {
        *d = 0;
        return false;
    }
}

