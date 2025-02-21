#include <memory>
#include <iostream>

#include <verilated.h>
#include "VTop.h"

int main(int argc, char** argv) {
    const std::unique_ptr<VerilatedContext> contextp{new VerilatedContext};
    contextp->debug(0);
    const std::unique_ptr<VTop> top{new VTop{contextp.get(), "VRISCV"}};

    top->rst_n = 1;
    top->clk = 0;
    unsigned long i = 0L;

    while (!contextp->gotFinish()) {
        top->clk = 1;
        top->eval();
        top->clk = 0;
        top->eval();
        i++;
    }

    top->final();

    std::cout << "finsihed after " << i << " cycles" << std::endl;

    return 0;
}
