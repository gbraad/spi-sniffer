/* SPI bus sniffer, waits for a configured command, notifies and provides data
 * upon this command reception.
 */

module SPI_decode(
  input clk,
  input start,
  input CSN,
  input SCK,
  input MOSI,
  input MISO,
  input [7:0] cmd,
  output reg ready,
  output reg [7:0] data);

//input  clk, start, CSN, SCK, MOSI, MISO, [7:0] cmd;
//output ready, [7:0] data;

//wire [7:0] cmd;
reg [7:0] cmd_buf;
reg [15:0] data_buf;
//assign data = data_buf[7:0];

//reg ready;
reg [1:0] state = 0;

// sync SCK to the FPGA clock using a 3-bits shift register
reg [2:0] SCKr;  always @(posedge clk) SCKr <= {SCKr[1:0], SCK};
wire SCK_risingedge = (SCKr[2:1]==2'b01);  // now we can detect SCK rising edges
wire SCK_fallingedge = (SCKr[2:1]==2'b10);  // and falling edges

// same thing for CSN
reg [2:0] CSNr;  always @(posedge clk) CSNr <= {CSNr[1:0], CSN};
wire CSN_active = ~CSNr[1];  // CSN is active low
wire CSN_startmessage = (CSNr[2:1]==2'b10);  // message starts at falling edge
wire CSN_endmessage = (CSNr[2:1]==2'b01);  // message stops at rising edge

// and for MOSI
reg [1:0] MOSIr;  always @(posedge clk) MOSIr <= {MOSIr[0], MOSI};
wire MOSI_data = MOSIr[1];

reg [7:0] bitcnt;
/*
always @(posedge clk)
begin
  if (!CSN_active)
  begin
    bitcnt <= 4'b0000;
    ready <= 0;
    state <= start;
  end
  else if (SCK_risingedge && state)
  begin
    bitcnt = bitcnt + 4'b0001;
    data_buf = {data_buf[14:0], MOSI_data};
    if (bitcnt == 4'd15)
    begin
      state = 0;
      data = data_buf[15:8];
      ready = 1;
//      if (data_buf[15:8] == cmd)
//        ready <= 1;
    end
  end
//  begin
//    data_buf[7:0] <= 8'h59; // 'Y'
//    state <= 0;
//    ready <= 1;
//  end
end
*/
always @(posedge clk)
begin
  case (state)
  0: begin
      if (start) state <= 1;
      ready <= 0;
    end
  1: begin
      if (CSN_startmessage) begin
        bitcnt <= 0;
        state <= 2;
      end
    end
  2: begin
      if (SCK_risingedge) begin
        bitcnt <= bitcnt + 4'b0001;
        data_buf <= {data_buf[14:0], MOSI_data};
      end
      if (CSN_endmessage) begin
        if (bitcnt == 5'd16 && data_buf[15:8] == cmd) begin
          data <= data_buf[7:0];
          state <= 0;
          ready <= 1;
        end else
          bitcnt <= 0;
        /*
        if (bitcnt[2:0] == 3'd0)
          data <= bitcnt[7:3];
        else
          data <= 8'hFF;
        state <= 0;
        ready <= 1;
        */
      end
    end
  endcase
  /*
  if (!state) begin
    state <= start;
    ready <= 0;
  end else
    if (CSN_startmessage) begin
//      data_buf[15:0] <= 16'd0;
      bitcnt <= 0;
    end
    if (CSN_endmessage) begin
//      if (bitcnt == 5'd16) begin // && data_buf[15:8] == cmd) begin
//        data <= data_buf[7:0];
//        state <= 0;
//        ready <= 1;
//      end else
//        bitcnt <= 0;
      data <= bitcnt;
      state <= 0;
      ready <= 1;
    end
    if (SCK_risingedge) begin
      bitcnt <= bitcnt + 4'b0001;
      data_buf <= {data_buf[14:0], MOSI_data};
    end
  */
end

endmodule
