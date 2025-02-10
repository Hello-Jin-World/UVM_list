`timescale 1ns / 1ps
`include "uvm_macros.svh"
import uvm_pkg::*;
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/12/21 22:21:55
// Design Name: 
// Module Name: I2C_UVM
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


interface i2c_interface ();
    logic        PCLK;
    logic        PRESET;
    logic [ 3:0] PADDR;
    logic        PWRITE;
    logic        PSEL;
    logic        PENABLE;
    logic [31:0] PWDATA;
    logic [31:0] PRDATA;
    logic        PREADY;
    logic        write;
    wire         SDA;
    logic        SCL;

    assign SDA = !write ? 1'b0 : 1'bz;
endinterface  //i2c_interface

class seq_item extends uvm_sequence_item;
    logic      [ 3:0] addr;
    logic      [ 3:0] addr_i2c_addr;
    logic      [ 3:0] addr_i2c_wData;
    rand logic [ 7:0] i2c_addr;
    rand logic [ 7:0] i2c_wData;
    logic      [31:0] rData;
    logic             write;
    logic      [ 7:0] got_addr;
    logic      [ 7:0] got_wData;

    constraint addr_C {
        addr_i2c_addr == 4'h0c;
        addr_i2c_wData == 4'h08;
    }

    function new(input string name = "seq_item");
        super.new(name);
    endfunction  //new()

    `uvm_object_utils_begin(seq_item)  // macro
        `uvm_field_int(addr, UVM_DEFAULT)  // There is not ";"
        `uvm_field_int(addr_i2c_addr, UVM_DEFAULT)  // There is not ";"
        `uvm_field_int(addr_i2c_wData, UVM_DEFAULT)
        `uvm_field_int(i2c_addr, UVM_DEFAULT)
        `uvm_field_int(i2c_wData, UVM_DEFAULT)
        `uvm_field_int(rData, UVM_DEFAULT)
        `uvm_field_int(write, UVM_DEFAULT)
        `uvm_field_int(got_addr, UVM_DEFAULT)
        `uvm_field_int(got_wData, UVM_DEFAULT)
    `uvm_object_utils_end


endclass  //seq_item extends uvm_sequence_item

class i2c_sequence extends uvm_sequence;
    `uvm_object_utils(i2c_sequence)

    seq_item i2c_seq_item;  // handler

    function new(input string name = "i2c_sequence");
        super.new(name);
    endfunction  //new()

    virtual task body();
        i2c_seq_item =
            seq_item::type_id::create("SEQ_ITEM");  // create instance
        repeat (10000) begin
            start_item(i2c_seq_item);
            i2c_seq_item.randomize();
            `uvm_info("SEQ", "Data send to Driver", UVM_NONE);
            finish_item(i2c_seq_item);
        end
    endtask
endclass  //i2c_sequence extends uvm_sequence

class i2c_driver extends uvm_driver #(seq_item);  // receive seq_time
    `uvm_component_utils(i2c_driver)

    virtual i2c_interface i2cIntf;
    seq_item              i2c_seq_item;

    function new(input string name = "i2c_driver", uvm_component c);
        super.new(name, c);
    endfunction  //new()

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        i2c_seq_item = seq_item::type_id::create("SEQ_ITEM", this);
        if (!uvm_config_db#(virtual i2c_interface)::get(
                this, ",", "i2cIntf", i2cIntf
            ))
            `uvm_fatal(get_name(), "Unable to access adder interface");
    endfunction

    virtual function void start_of_simulation_phase(uvm_phase phase);
        $display("display start of simulation phase!");
    endfunction

    task reset_i2c();
        i2cIntf.PRESET  <= 1;
        i2cIntf.PSEL    <= 0;
        i2cIntf.PENABLE <= 0;
        i2cIntf.PWRITE  <= 0;
        i2cIntf.write   <= 1;
        #10;
        i2cIntf.PRESET <= 0;
    endtask  //reset

    virtual task run_phase(uvm_phase phase);
        $display("display run phase!");
        reset_i2c();
        forever begin
            seq_item_port.get_next_item(i2c_seq_item);
            `uvm_info("DRV", "Send data to DUT", UVM_NONE);
            // wait (i2cIntf.SCL == 1);
            // wait (i2cIntf.SDA == 1);
            //////////////////////////      RANDOM ADDRESS       //////////////////////////// 
            i2cIntf.PSEL    = 1'b1;
            i2cIntf.PENABLE = 1'b1;
            i2cIntf.PWRITE  = 1'b1;
            i2cIntf.PADDR   = 8'h0c;
            i2cIntf.PWDATA  = {23'b0, i2c_seq_item.i2c_addr[6:0], 1'b1};
            #20;
            i2cIntf.PENABLE = 1'b0;
            i2cIntf.PWRITE  = 1'b0;
            #20;
            ////////////////////////////////////////////////////////////////////////////////

            //////////////////////////    RANDOM WRITE DATA     //////////////////////////// 
            i2cIntf.PENABLE = 1'b1;
            i2cIntf.PWRITE  = 1'b1;
            i2cIntf.PADDR   = 8'h08;
            i2cIntf.PWDATA  = {24'b0, i2c_seq_item.i2c_wData};
            #20;
            i2cIntf.PENABLE = 1'b0;
            i2cIntf.PWRITE  = 1'b0;
            #20;
            ////////////////////////////////////////////////////////////////////////////////

            ////////////////////////    CCR DATA, START BIT     //////////////////////////// 
            i2cIntf.PENABLE = 1'b1;
            i2cIntf.PWRITE  = 1'b1;
            i2cIntf.PADDR   = 8'h00;
            i2cIntf.PWDATA  = {21'b0, 1'b1, 10'b0};  // START BIT 1
            #20;
            i2cIntf.PENABLE = 1'b0;
            i2cIntf.PWRITE  = 1'b0;
            #5;
            // i2cIntf.PADDR   = 8'h04;
            ////////////////////////////////////////////////////////////////////////////////

            /////////////////////////    WAIT DUT RESPONSE     /////////////////////////////
            i2cIntf.PSEL = 1'b0;
            repeat (9) @(posedge i2cIntf.SCL);
            // i2cIntf.PADDR   = 8'h04;
            i2cIntf.write = 0;
            @(negedge i2cIntf.SCL);
            i2cIntf.write = 1;
            repeat (9) @(posedge i2cIntf.SCL);
            ////////////////////////////////////////////////////////////////////////////////

            /////////////////////////    FOR DUT STABILITY      ////////////////////////////
            wait (i2cIntf.SCL == 1);
            wait (i2cIntf.SDA == 1);
            ////////////////////////////////////////////////////////////////////////////////
            seq_item_port.item_done();
        end
    endtask  //run_phase
endclass  //i2c_driver extends uvm_driver #(seq_item)

class i2c_monitor extends uvm_monitor;
    `uvm_component_utils(i2c_monitor)

    uvm_analysis_port #(seq_item) send;
    virtual i2c_interface i2cIntf;
    seq_item i2c_seq_item;

    logic [7:0] read_i2c_addr, read_i2c_wData;
    logic [7:0] random_i2c_addr, random_i2c_wData;

    function new(input string name = "i2c_monitor", uvm_component c);
        super.new(name, c);
        send = new("WRITE", this);
    endfunction  //new()

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        i2c_seq_item = seq_item::type_id::create("SEQ_ITEM", this);
        if (!uvm_config_db#(virtual i2c_interface)::get(
                this, "", "i2cIntf", i2cIntf
            )) begin
            `uvm_fatal(get_name(), "Unable to access reg interface");
        end
    endfunction

    virtual task run_phase(uvm_phase phase);
        forever begin
            ///////////////////     GETTING SOFTWARE RANDOM DATA      ///////////////////
            @(posedge i2cIntf.PWRITE);
            random_i2c_addr = i2cIntf.PWDATA[7:0];
            @(posedge i2cIntf.PWRITE);
            random_i2c_wData = i2cIntf.PWDATA[7:0];
            /////////////////////////////////////////////////////////////////////////////

            ///////////////////      STORE DUT SDA DATA AS 0 OR 1       //////////////////
            for (int i = 0; i < 8; i++) begin
                @(posedge i2cIntf.SCL);
                if (i2cIntf.SDA) begin
                    read_i2c_addr[7-i] = 1'b1;
                end else begin
                    read_i2c_addr[7-i] = 1'b0;
                end
            end

            @(posedge i2cIntf.SCL);

            for (int i = 0; i < 8; i++) begin
                @(posedge i2cIntf.SCL);
                if (i2cIntf.SDA) begin
                    read_i2c_wData[7-i] = 1'b1;
                end else begin
                    read_i2c_wData[7-i] = 1'b0;
                end
            end
            /////////////////////////////////////////////////////////////////////////////
            i2c_seq_item.rData     = i2cIntf.PRDATA;
            i2c_seq_item.addr      = i2cIntf.PADDR;

            ///////////////     TRANSMIT SOFTWARE GOLDEN DATA TO SCB     ////////////////
            i2c_seq_item.i2c_addr  = random_i2c_addr;
            i2c_seq_item.i2c_wData = random_i2c_wData;
            /////////////////////////////////////////////////////////////////////////////

            ///////////////     TRANSMIT HARDWARE RESULT DATA TO SCB     ////////////////
            i2c_seq_item.got_addr  = read_i2c_addr;
            i2c_seq_item.got_wData = read_i2c_wData;
            /////////////////////////////////////////////////////////////////////////////
            `uvm_info("MON", "Send data to Scoreboard", UVM_NONE);
            send.write(i2c_seq_item);
        end
    endtask  //run_phase
endclass  //i2c_monitor extends uvm_monitor

class i2c_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(i2c_scoreboard)

    uvm_analysis_imp #(seq_item, i2c_scoreboard) recv;

    int total_cnt, pass_cnt, fail_cnt;
    // logic [31:0] scb_moder, scb_idr, scb_odr;

    function new(input string name = "i2c_scoreboard", uvm_component c);
        super.new(name, c);
        recv = new("READ", this);
        total_cnt   = 0;
        pass_cnt    = 0;
        fail_cnt    = 0;
    endfunction  //new()

    virtual function void write(seq_item data);
        // `uvm_info("SCB", "Data received from Monitor", UVM_NONE);

        if (data.got_addr == data.i2c_addr && data.got_wData == data.i2c_wData) begin
            `uvm_info(
                "SCB",
                $sformatf(
                    "PASS!!!, ADDR -> hw: %8b == sw: %8b  /  DATA-> hw: %8b == sw: %8b",
                    data.got_addr, data.i2c_addr, data.got_wData,
                    data.i2c_wData), UVM_NONE);
            pass_cnt++;
        end else begin
            `uvm_info(
                "SCB",
                $sformatf(
                    "FAIL..., ADDR -> hw: %8b != sw: %8b  /  DATA-> hw: %8b != sw: %8b",
                    data.got_addr, data.i2c_addr, data.got_wData,
                    data.i2c_wData), UVM_NONE);
            fail_cnt++;
        end
        total_cnt++;
        data.print(uvm_default_line_printer);

        $display("====================================");
        $display("Total Test : %d ", total_cnt);
        $display("========     Oper Result    ========");
        $display(" Pass Test : %d ", pass_cnt);
        $display(" Fail Test : %d ", fail_cnt);
        $display("====================================");
    endfunction
endclass  //i2c_scoreboard extends uvm_scoreboard;

class i2c_agent extends uvm_agent;
    `uvm_component_utils(i2c_agent)

    i2c_monitor i2cMonitor;
    i2c_driver i2cDriver;
    uvm_sequencer #(seq_item) i2cSequencer;

    function new(input string name = "i2c_agent", uvm_component c);
        super.new(name, c);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        i2cMonitor   = i2c_monitor::type_id::create("MON", this);
        i2cDriver    = i2c_driver::type_id::create("DRV", this);
        i2cSequencer = uvm_sequencer#(seq_item)::type_id::create("SQR", this);
        //Create Instance        
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        i2cDriver.seq_item_port.connect(i2cSequencer.seq_item_export);
    endfunction
endclass  //i2c_agent extends uvm_agent

covergroup pkt_cg with function sample (seq_item i2c_seq_item);
    coverpoint i2c_seq_item.i2c_addr;
    coverpoint i2c_seq_item.i2c_wData;
endgroup

class packet_coverage extends uvm_subscriber #(seq_item);
    `uvm_component_utils(packet_coverage)

    pkt_cg tr_cov;
    bit coverage_enable = 1;

    function new(input string name = "packet_coverage", uvm_component c);
        super.new(name, c);
    endfunction  //new()

    virtual function void build_phase(uvm_phase phase);
        if (coverage_enable) begin
            tr_cov = new();
        end
    endfunction

    virtual function void write(seq_item data);
        if (coverage_enable) begin
            tr_cov.sample(data);
            $display("====================================");
            $display("Coverage = %0.2f %%", tr_cov.get_inst_coverage());
            $display("====================================");
        end
    endfunction
endclass

class i2c_env extends uvm_env;
    `uvm_component_utils(i2c_env)

    i2c_scoreboard i2cScoreboard;
    i2c_agent i2cAgent;
    packet_coverage cov_comp;

    function new(input string name = "i2c_env", uvm_component c);
        super.new(name, c);
    endfunction  //new()

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        i2cScoreboard = i2c_scoreboard::type_id::create("SCB", this);
        i2cAgent      = i2c_agent::type_id::create("AGENT", this);
        cov_comp      = packet_coverage::type_id::create("cov_comp", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        i2cAgent.i2cMonitor.send.connect(i2cScoreboard.recv);
        i2cAgent.i2cMonitor.send.connect(cov_comp.analysis_export);
    endfunction
endclass  //i2c_env extendsuvm_env;

class i2c_test extends uvm_test;
    `uvm_component_utils(i2c_test)

    i2c_sequence i2cSequence;
    i2c_env i2cEnv;

    function new(input string name = "i2c_test", uvm_component c);
        super.new(name, c);
    endfunction  //new()

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        i2cSequence = i2c_sequence::type_id::create("SEQ", this);
        i2cEnv      = i2c_env::type_id::create("ENV", this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        phase.raise_objection(this);
        i2cSequence.start(i2cEnv.i2cAgent.i2cSequencer);
        phase.drop_objection(this);
    endtask
endclass  //i2c_test extends uvm_test

module I2C_UVM ();

    i2c_interface i2cIntf ();
    i2c_test i2ctest;

    I2C_Master dut (
        .PCLK   (i2cIntf.PCLK),
        .PRESET (i2cIntf.PRESET),
        .PADDR  (i2cIntf.PADDR),
        .PWRITE (i2cIntf.PWRITE),
        .PSEL   (i2cIntf.PSEL),
        .PENABLE(i2cIntf.PENABLE),
        .PWDATA (i2cIntf.PWDATA),
        .PRDATA (i2cIntf.PRDATA),
        .PREADY (i2cIntf.PREADY),
        .SDA    (i2cIntf.SDA),
        .SCL    (i2cIntf.SCL)
    );

    always #5 i2cIntf.PCLK = ~i2cIntf.PCLK;

    initial begin
        i2cIntf.PCLK   = 0;
        i2cIntf.PRESET = 0;
        #10;
        i2cIntf.PRESET = 1;
    end

    initial begin
        i2ctest = new("32bit Register UVM Verification", null);
        uvm_config_db#(virtual i2c_interface)::set(null, "*", "i2cIntf",
                                                   i2cIntf);
        // db -> type : virtual i2c_interface ,       key : "i2cIntf" value : i2cIntf
        run_test();
    end
endmodule
