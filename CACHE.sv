module CACHE #(
        parameter INDEX_BITS = 13,
        parameter DATA_WIDTH = 31,
        parameter TAG_BITS = 17,
        parameter OFF_BITS = 2
)(  
        input logic clk, reset,

        //inputs from cpu
        input logic cpu_req, cpu_write,
        input logic[DATA_WIDTH:0] cpu_address,
        input logic[DATA_WIDTH:0] write_data_cpu,

        //inputs from ram
        input logic mem_ready,
        input logic[DATA_WIDTH:0] read_data_mem,

        //outputs to ram
        output logic[DATA_WIDTH:0] mem_addr,
        output logic[DATA_WIDTH:0] write_data_mem,
        output logic mem_write, mem_req,

        //outputs to cpu
        output logic[DATA_WIDTH:0] read_data_cpu,
        output logic cpu_ready
);
    //==============================================
    //DATAPATH
    //PART A
    //==============================================
    logic[DATA_WIDTH:0] ram_addr [0:8192]; //ram where the address will be stored
    logic[TAG_BITS-1:0] tag_ram [0:8192]; //will store every tag from every address
    logic[DATA_WIDTH:0] ram_data [0:8192]; //this is the data that will be stored in the ram

    logic [1:0] status_bits [8192:0]; //matrice that stores the valid bits and dirty bits status_bits[index][0] --> valid bit status_bits[index][1] ---> dirty bit

    logic[DATA_WIDTH:0] cpu_addr_aux;  //aux for the data of address
    logic[DATA_WIDTH:0] wdata_aux; //aux for the data of write_data
    logic[TAG_BITS-1:0] tag_from_ram; //this wire will take the index and see which is the tag on tag_ram of that index

    logic hit;
    logic write_or_read;

    //PART B
    logic[TAG_BITS-1:0] tag;        //it's the tag 
    logic[INDEX_BITS-1:0] index;    //it's the index of address
    logic[OFF_BITS-1:0] offset;     //it's the offset of address


    assign tag = cpu_addr_aux[DATA_WIDTH:DATA_WIDTH-TAG_BITS + 1];
    assign index = cpu_addr_aux[DATA_WIDTH-TAG_BITS: DATA_WIDTH-TAG_BITS-INDEX_BITS+1];
    assign offset = cpu_addr_aux[DATA_WIDTH-TAG_BITS-INDEX_BITS: DATA_WIDTH-TAG_BITS-INDEX_BITS-OFF_BITS+1];

    
    assign tag_from_ram = tag_ram[index];  //then we will use this wire to compare with the curr tag from tag's wire
    assign hit = ((tag_from_ram == tag) && (status_bits[index][0])) ? 1'b1 : 1'b0;  //see if the tags are equal and check if it's valid

    //====================================
    //FSM - STATES
    //====================================
    typedef enum logic[2:0] {
        IDLE = 0,
        COMPARE = 1,
        WRITE_BACK = 2,
        ALLOCATE = 3
    } states;  

    states curr, next_state;

    //enables
    logic en_compare, en_idle, en_write_b, en_allocate1, en_allocate2;

    initial begin
        for(int i = 0; i < 8192; i++) begin
            status_bits[i][0] = 0;
            status_bits[i][1] = 0;
            ram_data[i] = 0;
            tag_ram[i] = 0;
        end
    end

    always_ff @(posedge clk) begin
        if(reset) begin
                curr <= IDLE;
                
        end else begin
                if(en_idle) begin
                        ram_addr[index] <= cpu_address;
                        cpu_addr_aux <= cpu_address;
                        wdata_aux <= write_data_cpu; 
                        write_or_read <= cpu_write;
                end

                if(en_compare) begin  
                        ram_data[index] <= wdata_aux;
                        status_bits[index][1] <= 1;
                end

                if(en_write_b) begin
                        mem_addr <= {tag_from_ram, index, offset};
                        write_data_mem <= ram_data[index];
                end

                if(en_allocate1) begin
                        mem_addr <= cpu_addr_aux;
                end
                
                if(en_allocate2) begin
                        tag_ram[index] <= tag;
                        status_bits[index][0] <= 1;
                        status_bits[index][1] <= 0;
                end
                
                curr <= next_state;
        end
    end

    always_comb begin
                next_state = curr;

                en_idle = 1'b0;
                en_compare = 1'b0;
                en_write_b = 1'b0;
                en_allocate1 = 1'b0;
                en_allocate2 = 1'b0;

                cpu_ready = 1'b0;
                mem_req = 1'b0;
                mem_write = 1'b0;

                        case(curr)
                                IDLE: begin
                                        if(cpu_req) begin
                                                en_idle = 1'b1;
                                                next_state = COMPARE;
                                        end else begin
                                                en_idle = 1'b0;
                                                next_state = IDLE;
                                        end
                                end
                                COMPARE: begin
                                        if(hit) begin
                                                if(write_or_read) begin
                                                        en_compare = 1'b1;
                                                        cpu_ready = 1'b1;
                                                        next_state = IDLE;
                                                end else if(!write_or_read) begin
                                                        cpu_ready = 1'b1;
                                                        read_data_cpu = ram_data[index];
                                                        next_state = IDLE;
                                                end 
                                        end else if(!hit && status_bits[index][1'b1]) begin
                                                next_state = WRITE_BACK;
                                        end else if(!hit && !status_bits[index][1'b1]) begin
                                                next_state = ALLOCATE;
                                        end
                                end
                                WRITE_BACK: begin
                                        mem_req = 1'b1;
                                        mem_write = 1'b1;
                                        en_write_b = 1'b1;
                                        if(mem_ready) begin
                                                mem_req = 1'b0;
                                                mem_write = 1'b0;
                                                next_state = ALLOCATE;
                                        end else begin
                                                next_state = WRITE_BACK;
                                        end
                                end
                                ALLOCATE: begin
                                        mem_req = 1'b1;
                                        mem_write = 1'b0;
                                        en_allocate1 = 1'b1;
                                        if(mem_ready) begin
                                                en_allocate2 = 1'b1;
                                                ram_data[index] = read_data_mem;
                                                mem_req = 1'b0;
                                                next_state = COMPARE;
                                        end else begin
                                                en_allocate2 = 1'b0;
                                                next_state = ALLOCATE;
                                        end
                                end
                        endcase
        end

endmodule
