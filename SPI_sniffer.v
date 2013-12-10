/* Top module */

/*
module SPI_sniffer(cmd_csn, cmd_sck, cmd_mosi, cmd_miso, cmd_irqn,
                   sniff_csn, sniff_sck, sniff_mosi, sniff_miso);
wire status_w;
wire [7:0] command_w, data_in_w, data_out_w;
SPI_slave cmd(.csn(cmd_csn), .sck(cmd_sck), .mosi(cmd_mosi), .miso(cmd_miso), .irqn(cmd_irqn),
              .command(command_w), .data_in(data_in_w), .status(status_w), .data_out(data_out_w));

SPI_sniff sniff(.csn(sniff_csn), .sck(sniff_sck), .mosi(sniff_mosi), .miso(sniff_miso));

endmodule
*/

module SPI_sniffer(clk, nrst, tx_in, tx_out, test_out,
                   csn, sck, mosi, miso);
input clk, nrst, tx_in;
output tx_out;
output test_out;
input csn, sck, mosi, miso;

reg tx_start;
reg decoder_start;
wire decoder_ready;
wire tx_busy;
reg test_out;
wire [7:0] data;
reg [7:0] bufdata;
wire [4:0] highnibble = bufdata[7:4];
wire [4:0] lownibble = bufdata[3:0];
reg [7:0] tstdata;
//wire [4:0] highnibble = tstdata[7:4];
//wire [4:0] lownibble = tstdata[3:0];

reg [7:0] chardata;
reg [1:0] nhexout; // first nibble, second nibble, space
reg [7:0] cmd; // command to trace

wire rst = ~nrst;

async_transmitter TX(.clk(~clk), .TxD_start(tx_start), .TxD_data(chardata),
                     .TxD(tx_out), .TxD_busy(tx_busy));

SPI_decode decoder(.clk(~clk), .start(decoder_start),
                   .CSN(csn), .SCK(sck), .MOSI(mosi), .MISO(miso), .cmd(cmd),
                   .ready(decoder_ready), .data(data));

reg [1:0] phase;
reg [14:0] cnt;

always @(posedge clk) //, negedge nrst)
  if (!nrst) begin
     test_out <= 0;
     tstdata <= 8'hBC;
     // Async TX
	   tx_start <= 0;
	   chardata <= 8'h41; // 'A'
     // SPI decoder
     cmd <= 8'h25; // nRF24L01 command 'set channel'
	   cnt <= 0;
     decoder_start <= 0;
     phase <= 0;
	 end
  else
    case (phase)
      2'd0: begin // start SPI decoding
          decoder_start <= 1;
          phase = 1;
        end
      2'd1: begin // waiting for sniffer
          if (decoder_ready) begin
            phase = 2;
            nhexout = 0;
            bufdata <= data;
          end
        end
      2'd2: begin // output of received byte in hex form
          // Clear the SPI decoder
          decoder_start <= 0;
          if (tx_busy)
            tx_start <= 0;
          else
            case (nhexout)
              2'd0: begin
                  if (highnibble < 4'ha)
                    chardata = 8'h30 + highnibble;
                  else
                    chardata = 8'h37 + highnibble;
                  tx_start = 1;
                  nhexout <= 2'd1;
                end
              2'd1: begin
                  if (lownibble < 4'ha)
                    chardata = 8'h30 + lownibble;
                  else
                    chardata = 8'h37 + lownibble;
                  tx_start = 1;
                  nhexout <= 2'd2;
                end
              2'd2: begin
                  chardata = 8'h20; // space
                  tx_start = 1;
                  nhexout <= 2'd3;
                end
              default: begin
                  phase <= 0;
                end
            endcase
          end
      default: begin
        end
    endcase
    /*
    begin
      if (tx_busy)
        begin
          cnt <= 0;
          tx_start <= 0;
        end
      else if (ready)
        begin
          cnt <= cnt + 1;
          if (cnt == 15'd26042)
            begin
             cnt <= 0;
             start <= 1;
             test_out <= ~test_out;
            end
        end
    end
    */

endmodule
