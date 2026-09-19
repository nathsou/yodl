#include <memory>
#include <iostream>

#include <verilated.h>
#include "VTop.h"

int main(int argc, char** argv) {
    constexpr unsigned long reset_cycles = 8;
    constexpr unsigned long timeout_cycles = 20'000'000;
    const std::unique_ptr<VerilatedContext> contextp{new VerilatedContext};
    contextp->debug(0);
    const std::unique_ptr<VTop> top{new VTop{contextp.get(), "VRISCV"}};

    top->rst_n = 0;
    top->clk = 0;
    unsigned long i = 0L;

    while (!contextp->gotFinish() && !top->halted && !top->trap && i < timeout_cycles) {
        if (i == reset_cycles) {
            top->rst_n = 1;
        }
        top->clk = 1;
        top->eval();
        top->clk = 0;
        top->eval();
        i++;
    }

    top->final();

    if (top->trap) {
        std::cerr << "RISC-V core trapped on an unsupported instruction after " << i << " cycles"
                  << std::endl;
        return 3;
    }

    if (!top->halted && !contextp->gotFinish()) {
        std::cerr << "RISC-V simulation timed out after " << i << " cycles" << std::endl;
        return 2;
    }

    if (top->led != 1) {
        std::cerr << "RISC-V self-test failed with result " << static_cast<unsigned>(top->led)
                  << " after " << i << " cycles" << std::endl;
        return 1;
    }

    std::cout << "RISC-V self-test passed after " << i << " cycles" << std::endl;

    return 0;
}
