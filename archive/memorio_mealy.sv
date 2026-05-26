module MemoryOrIOModule (CLK, RESET, ALE, CS, RD, WR, ADDRESS, DATA);
    
    parameter ADDR_WIDTH = 19;
    parameter DATA_WIDTH = 8;
    parameter NUM_UNITS = (1 << ADDR_WIDTH); // Adjust based on memory or I/O size
    parameter INIT_FILE = "memory_init.mem"; // File to load initial memory contents

    input wire CLK;
    input wire RESET;
    input wire ALE; // Address Latch Enable
    input wire CS; // Chip Select. Active high
    input wire RD; // Read Enable. Active low
    input wire WR; // Write Enable. Active low
    input wire [ADDR_WIDTH-1:0] ADDRESS;
    inout wire [DATA_WIDTH-1:0] DATA;

    // Control signals between ControlSequencer and Datapath
    wire LA, OE, WE, RE;

    Datapath #(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .NUM_UNITS(NUM_UNITS), .INIT_FILE(INIT_FILE)) datapath (CLK, RESET, ADDRESS, DATA, LA, OE, WE, RE);
    ControlSequencer controlSequencer (CLK, RESET, ALE, CS, RD, WR, LA, OE, WE, RE);

endmodule

module Datapath (CLK, RESET, ADDRESS, DATA, LA, OE, WE, RE);
    
    parameter ADDR_WIDTH = 19;
    parameter DATA_WIDTH = 8;
    parameter NUM_UNITS = (1 << ADDR_WIDTH);
    parameter INIT_FILE = "memory_init.mem"; // File to load initial memory contents

    input wire CLK;
    input wire RESET;
    input wire [ADDR_WIDTH-1:0] ADDRESS;
    inout wire [DATA_WIDTH-1:0] DATA;
    input wire LA; // From ControlSequencer
    input wire OE; // From ControlSequencer
    input wire WE; // From ControlSequencer
    input wire RE; // From ControlSequencer
    
    reg [DATA_WIDTH-1:0] DOUT;
    reg [ADDR_WIDTH-1:0] MEM_INDEX;
    reg [DATA_WIDTH-1:0] MEM[NUM_UNITS-1:0];

    // Tristate buffer control for bidirectional Data bus
    assign DATA = OE ? DOUT : {DATA_WIDTH{1'bz}};

    // Load initial memory contents from file
    initial begin
        if (INIT_FILE != "") $readmemh(INIT_FILE, MEM);
    end

    // Load DOUT with data from memory and capture data from the bus and store in memory
    always_ff @(posedge CLK) begin
        if (LA)
            MEM_INDEX <= ADDRESS;
        if (RE)
            DOUT <= MEM[MEM_INDEX]; // Prepare data to be output on the bus
        if (WE)
            MEM[MEM_INDEX] <= DATA; // Capture the data from the bus
    end

endmodule

module ControlSequencer (CLK, RESET, ALE, CS, RD, WR, LA, OE, WE, RE);

    input wire CLK;
    input wire RESET;
    input wire ALE; // Address Latch Enable
    input wire CS; // Chip Select. Active high
    input wire RD; // Read Enable. Active low
    input wire WR; // Write Enable. Active low
    output reg LA; // To Datapath
    output reg OE; // To Datapath
    output reg WE; // To Datapath
    output reg RE; // To Datapath

    // State definitions using one-hot encoding.
    typedef enum logic [3:0] {
        IDLE  = 4'b0001,
        LOAD_ADDR = 4'b0010,
        READ  = 4'b0100,
        WRITE = 4'b1000
    } State_t;

    State_t State, NextState;

    // First procedural block to model sequential logic
    always_ff @(posedge CLK) begin
        if (RESET)
            State <= IDLE;
        else
            State <= NextState;
    end

    // Second procedural block to model output combinational logic and next state logic
    always_comb begin
        NextState = State;
        case (State)
            IDLE: begin
                {LA, WE, RE, OE} = '0;
                if (CS && ALE) begin
                    LA = '1;
                    NextState = LOAD_ADDR;
                end
            end
            LOAD_ADDR: begin
                if (!RD) begin
                    RE = '1;
                    NextState = READ;
                end
                else if (!WR) begin
                    WE = '1;
                    NextState = WRITE;
                end
            end
            READ: begin
                OE = '1;
                NextState = IDLE;
            end
            WRITE: begin
                NextState = IDLE;
            end
        endcase
    end

endmodule
