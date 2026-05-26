// Interface for the Intel 8088 with modports for Processor and Peripheral  

interface Intel8088Pins(input bit CLK, RESET);

    // Input pins to the 8088 processor
    logic HOLD, READY, NMI, INTR, MNMX, TEST, HLDA, IOM, WR, RD, SSO, ALE, DTR, DEN, INTA;

    tri [7:0] AD;
    tri [19:8] A;

    tri [7:0] Data;
    logic [19:0] Address;

    // Processor modport (what the processor can 'see')
    modport Processor (
        input HOLD, READY, NMI, INTR, MNMX, TEST,
        output HLDA, IOM, WR, RD, SSO, ALE, DTR, DEN, INTA,
        output A,
        inout AD,
        input CLK, RESET
    );

    // Peripheral modport (what the peripheral can 'see')
    modport Peripheral (
        input WR, RD, ALE,
        input CLK, RESET,
        input Address,
        inout Data
    );
    
endinterface
