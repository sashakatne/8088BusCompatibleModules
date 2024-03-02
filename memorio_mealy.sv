module MemoryOrIOModule (CLK, RESET, CS, OE, WR, Address, Data);
    
    parameter ADDR_WIDTH = 20;  // Width of the 8088 address bus
    parameter DATA_WIDTH = 8;   // Width of the 8088 data bus
    parameter BASE_ADDR = 0;    // Base address for this module
    parameter NUM_UNITS = 512 * 1024;  // Number of addressable units
    parameter INIT_FILE = "memory_init.mem"; // File to load initial memory contents

    input wire CLK;
    input wire RESET;
    input wire CS; // Chip Select. Active high
    input wire OE; // Output Enable. Active low
    input wire WR; // Write Enable. Active low
    input wire [ADDR_WIDTH-1:0] Address;
    inout wire [DATA_WIDTH-1:0] Data;

    // Define the effective address width based on the number of addressable units
    localparam EFF_ADDR_WIDTH = $clog2(NUM_UNITS);

    // Adjust the memory array size based on the number of addressable units
    reg [DATA_WIDTH-1:0] mem[0:NUM_UNITS-1];

    // Internal signals for data bus handling
    reg [DATA_WIDTH-1:0] data_out;
    reg data_out_valid;

    // Calculate the index for the internal memory array
    wire [EFF_ADDR_WIDTH-1:0] mem_index = Address - BASE_ADDR;

    // State definitions
    typedef enum logic [2:0] {
        IDLE  = 3'b001,
        READ  = 3'b010,
        WRITE = 3'b100
    } State_t;

    State_t State, NextState;

    // First procedural block to model sequential logic
    always_ff @(posedge CLK) begin
        if (RESET) begin
            State <= IDLE;
        end else begin
            State <= NextState;
        end
    end

    // Second procedural block to model next state and output combinational logic
    always_comb begin
        // Default assignments for combinational logic
        NextState = State;
        data_out_valid = 1'b0;
        data_out = {DATA_WIDTH{1'b0}};

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
                if (CS && !OE) begin
                    data_out = mem[mem_index];  // Prepare data to be output on the bus
                    data_out_valid = 1'b1;
                end
                NextState = IDLE;
            end
            WRITE: begin
                if (CS && !WR) begin
                    mem[mem_index] = Data;  // Capture the data from the bus
                end
                NextState = IDLE;
            end
        endcase
    end

    // Tristate buffer control for bidirectional Data bus
    assign Data = data_out_valid ? data_out : {DATA_WIDTH{1'bz}};

    // Initial block to load memory contents from a file
    initial begin
        if (INIT_FILE != "") begin
            $readmemh(INIT_FILE, mem);
        end
    end

endmodule
