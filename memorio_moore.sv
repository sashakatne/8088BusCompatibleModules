module MemoryOrIOModule (CLK, RESET, CS, OE, WR, Address, Data);
    
    parameter ADDR_WIDTH = 20;  // Width of the 8088 address bus
    parameter DATA_WIDTH = 8;   // Width of the 8088 data bus
    parameter BASE_ADDR = 0;    // Base address for this module
    parameter NUM_UNITS = 512 * 1024;  // Number of addressable units
    parameter INIT_FILE = "memory_init.mem"; // File to load initial memory contents

    input wire CLK;
    input wire RESET;
    input wire CS; // Chip Select. Active high
    input wire OE; // Output Enable. Active low. This is equivalent to Read Enable
    input wire WR; // Write Enable. Active low
    input wire [ADDR_WIDTH-1:0] Address;
    inout wire [DATA_WIDTH-1:0] Data;

    // Define the effective address width based on the number of addressable units
    localparam EFF_ADDR_WIDTH = $clog2(NUM_UNITS);

    // Adjust the memory array size based on the number of addressable units
    reg [DATA_WIDTH-1:0] mem[NUM_UNITS-1:0];

    // Internal signals for data bus handling
    reg [DATA_WIDTH-1:0] data_out;
    reg data_out_valid;

    // Calculate the index for the internal memory array
    wire [EFF_ADDR_WIDTH-1:0] mem_index = Address - BASE_ADDR;

    // Tristate buffer control for bidirectional Data bus
    assign Data = data_out_valid ? data_out : {DATA_WIDTH{1'bz}};

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
        if (RESET) begin
            State <= IDLE;
        end else begin
            State <= NextState;
        end
    end

    // Second procedural block to model next state combinational logic
    always_comb begin
        // Default assignment for NextState
        NextState = State;

        case (State)
            IDLE: begin
                if (CS) begin
                    if (!OE && WR) begin
                        NextState = READ;
                    end else if (OE && !WR) begin
                        NextState = WRITE;
                    end
                end
            end
            READ: begin
                NextState = IDLE;
            end
            WRITE: begin
                NextState = IDLE;
            end
        endcase
    end

    // Third procedural block to model output combinational logic
    always_comb begin
        // Default assignments for outputs
        data_out_valid = 1'b0;
        data_out = {DATA_WIDTH{1'b0}};

        case (State)
            IDLE: begin
                // No action required in IDLE state
            end
            READ: begin
                // In Moore FSM, output is based on the state alone
                data_out = mem[mem_index];  // Prepare data to be output on the bus
                data_out_valid = 1'b1;
            end
            WRITE: begin
                mem[mem_index] = Data;  // Capture the data from the bus
            end
        endcase
    end

    // Initial block to load memory contents from a file
    initial begin
        if (INIT_FILE != "") begin
            $readmemh(INIT_FILE, mem);
        end
    end

endmodule
