// sim_main.cpp
// Verilator 5.x C++ wrapper for the AES testbench.
// Place alongside the Makefile in AES-master/.
//
// With --timing, Verilator drives the clock internally from the SV
// clk_gen module. We just call sim_main(), which runs until $finish.

#include "Vaes_tb.h"
#include "verilated.h"
#include <iostream>

int main(int argc, char** argv) {
    // Pass all command-line args (including +NUM_VECS=N) to the
    // Verilated runtime so $value$plusargs picks them up.
    const std::unique_ptr<VerilatedContext> contextp{new VerilatedContext};
    contextp->commandArgs(argc, argv);

    // Instantiate the top-level module.
    const std::unique_ptr<Vaes_tb> top{new Vaes_tb{contextp.get(), "TOP"}};

    // With --timing, Verilator handles all clock/delay scheduling.
    // We just loop until the simulation calls $finish or $fatal.
    while (!contextp->gotFinish()) {
        contextp->timeInc(1);
        top->eval();
    }

    top->final();
    return 0;
}
