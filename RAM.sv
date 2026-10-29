module RAM #(
        parameter DATA_WIDTH = 31,
        parameter INDEX_BITS = 13,
        parameter TAG_BITS = 17
)(
        input logic clk, reset,
        input logic mem_req, //Cache puts this bit 1 if it wants to start an operation
        input logic mem_write, //indicates the operation: 1 -> write | 0 -> read
        input logic[DATA_WIDTH:0] address, //address to check
        input logic[DATA_WIDTH:0] w_data, //data to write
        
        output logic[DATA_WIDTH:0] r_data, //data that ram gives to cache after write operation
        output logic mem_ready //confirms the operation on ram
);

        logic [DATA_WIDTH:0] ram [0:8192];
        logic [INDEX_BITS-1:0] index;
        logic [DATA_WIDTH:0] write_d;
        logic mem_write_aux;
        logic [3:0] latency; 

        typedef enum logic[1:0] {
                IDLE    = 0,
                WAIT    = 1,
                RESPOND = 2
        } states;

        states curr;

        initial begin
                for(int i = 0; i < 8192; i++) begin
                        ram[i] = 'b0;
                end
        end

        always_ff @(posedge clk) begin
                if(reset) begin
                        latency <= 4'd10;
                        mem_ready <= 1'b0;
                        write_d <= 'b0;
                        curr <= IDLE;
                
                end else begin
                        case(curr)
                                IDLE: begin
                                        if(mem_req) begin
                                                latency <= 4'd10;
                                                write_d <= w_data;
                                                mem_write_aux <= mem_write;
                                                index <= address[DATA_WIDTH-TAG_BITS:DATA_WIDTH-TAG_BITS-INDEX_BITS+1];
                                                mem_ready <= 1'b0;
                                                curr <= WAIT;
                                        end else begin
                                                mem_ready <= 1'b0;
                                                curr <= IDLE;
                                        end
                                end
                                WAIT: begin
                                        if(latency <= 4'd0) begin
                                                latency <= 4'd10;
                                                mem_ready <= 1'b0;
                                                curr <= RESPOND;
                                        end else begin
                                                latency <= latency - 1'b1;
                                                mem_ready <= 1'b0;
                                                curr <= WAIT;
                                        end
                                end
                                RESPOND: begin
                                        if(mem_write_aux) begin
                                                ram[index] <= write_d;
                                                mem_ready <= 1'b1;
                                                curr <= IDLE;
                                        end else begin
                                                mem_ready <= 1'b1;
                                                curr <= IDLE;
                                        end
                                end
                        endcase
                end
        end

        assign r_data = (!mem_write_aux) ? ram[index] : 'b0;
endmodule
