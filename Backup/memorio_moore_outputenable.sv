module MemoryOrIOModule (CLK, RESET, CS, RD, WR, ADDRESS, DATA);
    
    parameter ADDR_WIDTH = 20;  // Width of the 8088 address bus
    parameter DATA_WIDTH = 8;   // Width of the 8088 data bus
    parameter BASE_ADDR = 0;    // Base address for this module
    parameter NUM_UNITS = 512 * 1024;  // Number of addressable units
    parameter INIT_FILE = "memory_init.mem"; // File to load initial memory contents

    input wire CLK;
    input wire RESET;
    input wire CS; // Chip Select. Active high
    input wire RD; // Read Enable. Active low
    input wire WR; // Write Enable. Active low
    input wire [ADDR_WIDTH-1:0] ADDRESS;
    inout wire [DATA_WIDTH-1:0] DATA;

    // Define the effective address width based on the number of addressable units
    localparam EFF_ADDR_WIDTH = $clog2(NUM_UNITS);

    // Adjust the memory array size based on the number of addressable units
    reg [DATA_WIDTH-1:0] MEM[NUM_UNITS-1:0];

    // Internal signals for data bus handling
    reg [DATA_WIDTH-1:0] DOUT;
    reg OE; //Output Enable. Active high

    // Calculate the index for the internal memory array
    wire [EFF_ADDR_WIDTH-1:0] MEM_INDEX = ADDRESS - BASE_ADDR;

    // Tristate buffer control for bidirectional Data bus
    assign DATA = OE ? DOUT : {DATA_WIDTH{1'bz}};

    // State definitions
    typedef enum logic [2:0] {
        IDLE  = 3'b001,
        READ  = 3'b010,
        WRITE = 3'b100
    } State_t;

    State_t State, NextState;

    // First procedural block to model sequential logic
    // Synchronous reset design
    always_ff @(posedge CLK) begin
        if (RESET) State <= IDLE;
        else State <= NextState;
    end

    // Second procedural block to model next state combinational logic
    always_comb begin

        NextState = State;
        case (State)
            IDLE: begin
                if (CS) begin
                    if (!RD && WR) NextState = READ;
                    else if (RD && !WR) NextState = WRITE;
                end
            end
            READ:
                NextState = IDLE;
            WRITE:
                NextState = IDLE;
        endcase

    end

    // Third procedural block to model output combinational logic
    always_comb begin
        
        OE = '0;
        DOUT = {DATA_WIDTH{1'b0}};

        case (State)
            READ: begin
                DOUT = MEM[MEM_INDEX];  // Prepare data to be output on the bus
                OE = '1;
            end
            WRITE:
                MEM[MEM_INDEX] = DATA;  // Capture the data from the bus
        endcase

    end

    // Initial block to load memory contents from a file
    initial begin
        if (INIT_FILE != "") $readmemh(INIT_FILE, MEM);
    end

endmodule
