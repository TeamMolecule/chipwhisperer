`include "includes.v"
`default_nettype none

module cwlite_interface(  
    input wire         clk_usb,
      
    //GPIO_LED1 was removed from final version of CW-Lite design
    output wire        GPIO_LED2,
    output wire        GPIO_LED3,
    output wire        GPIO_LED4,
	 output wire        GPIO_LED5,
	 
	 /* FPGA - USB Interface */
	 inout wire [7:0]	USB_D,
	 input wire [7:0]	USB_Addr,
	 input wire			USB_RDn,
	 input wire			USB_WRn,
	 input wire			USB_CEn,
	 input wire			USB_ALEn,


	 /* ADC Interface */
	 input wire [9:0]   ADC_Data,
	 input wire        ADC_OR,
	 output wire       ADC_clk,
	 input wire			 ADC_clk_fb,
//	 input         DUT_CLK_i,
//	 input         DUT_trigger_i,
	 output wire       amp_gain,
	 output wire       amp_hilo,
	 
	 /* XMEGA Programming - not used, but need to ensure line is floating */
	 inout wire       target_PDID,
	 inout wire       target_PDIC,
	 
	 /* Spare Lines - AVR Programming */
	 output wire 		target_nRST,
	 input wire 		target_MISO,
	 output wire 		target_MOSI,
	 output wire 		target_SCK,
	 	 
	 /* Target IO Interfaces */
	 inout wire			target_io4, // Normally trigger
	 inout wire			target_io3, // Normally Spare / SmartCard Comms
	 inout wire			target_io2, // Normally RXD
	 inout wire			target_io1, // Normally TXD / SmartCard Reset
	 inout wire			target_hs1, // Clock from victim device
	 inout wire			target_hs2, // Clock to victim device
	 
	 inout wire			sc_rst,
	 inout wire			sc_clk,
	 inout wire			sc_io,
	 inout wire			sc_aux1,
	 inout wire			sc_aux2,

	 output wire		glitchout_highpwr, // high-speed glitch output
	 output wire		glitchout_lowpwr, // high-speed glitch output 
	 
	 output wire		target_npower,
	 
	 /* Various connections to USB Chip */
	 input wire			USB_ser0_tx_i,
	 output wire		USB_ser0_rx_o,

	 input wire			USB_spi0_sck_i,
	 input wire 		USB_spi0_mosi_i,
	 output wire 		USB_spi0_miso_o,
	 input wire			USB_spi0_cs0,
	 input wire			USB_treset_i,
	 
	 input wire			USB_sc_rst,
	 input wire 		USB_sc_clk,
	 input wire			USB_sc_aux1,
	 input wire			USB_sc_aux2,
	 input wire 		USB_spi2_txd2,
	 output wire		USB_spi2_rxd2,
	 
	 input wire       USB_spare1, //CS pin from SAM3U
	 input wire			USB_spare2, //LCD_D/C Pin (Data/Command) or CS pin TO SAM3U
	 
	 output wire		ext_mosi, //Pin 4 of external header
	 input wire			ext_miso, //Pin 3 of external header
	 output wire		ext_sck,  //Pin 2 of external header
	 output wire		lcd_cs,
	 output wire		lcd_dc,
	 output wire      avr_cs
	 //output wire		lcd_rst
	 );
	
	/* PDI Programming done from SAM, must float these wires
	   or programming will fail from weak pull-down on FPGA */
	//assign XMEGA_PDID = 1'bZ;
	//assign XMEGA_PDIC = 1'bZ;
	
	//wire [35:0] cs_control0;
	//wire [63:0] ila_trigbus;
	
	wire reset_i;
	assign reset_i = 0;
	
	wire reset_intermediate;
	wire clk_usb_buf;
	
		IBUFG IBUFG_inst (
	.O(clk_usb_buf),
	.I(clk_usb) );
	
	//Change in ICAP - clock now generated outside. 
	//TODO: Check skew is OK still
	wire clk_slow;
	reg [2:0] slowcnt;
	always @(posedge clk_usb_buf) begin
		slowcnt <= slowcnt + 3'd1;
	end
	assign clk_slow = slowcnt[2];
	
	wire reg_rst;
	wire [5:0] reg_addr;
	wire [15:0] reg_bcnt;
	wire [7:0] reg_datao;
	wire [7:0] reg_datai_cw;
	wire [7:0] reg_datai_reconfig;
	wire [7:0] reg_datai_glitch;
	wire [7:0] reg_datai_glitch2;
	wire [7:0] reg_datai_decode;
	wire [7:0] reg_datai_mmctarg;
	wire [7:0] reg_datai_mmctrig;
	wire [7:0] reg_datai_edgetrig;
	wire [7:0] reg_datai_clkdiv;
	wire [15:0] reg_size;
	wire reg_read;
	wire reg_write;
	wire reg_addrvalid;
	wire [5:0] reg_hypaddr;
	wire [15:0] reg_hyplen_cw;
	wire [15:0] reg_hyplen_glitch;
	wire [15:0] reg_hyplen_glitch2;
	wire [15:0] reg_hyplen_reconfig;
	wire [15:0] reg_hyplen_decode;
	wire [15:0] reg_hyplen_mmctarg;
	wire [15:0] reg_hyplen_mmctrig;
	wire [15:0] reg_hyplen_edgetrig;
	wire [15:0] reg_hyplen_clkdiv;
	
	wire [1:0] ext_trigger;
	wire extclk_mux;
	wire clkgen, adc_sample_clk;
	wire [1:0] glitchclk;
	wire enable_avrprog;
	wire advio_trigger_line;
	wire decode_trigger;
	wire mmc_trigger;
	wire edge_trigger;

	openadc_interface oadc(
		.reset_i(reset_i),
		.clk_adcint(clk_usb_buf),
		.clk_iface(clk_usb_buf),
		.clk_adcsample(adc_sample_clk),
		
		.USB_D(USB_D),
		.USB_Addr(USB_Addr),
		.USB_RDn(USB_RDn),
		.USB_WRn(USB_WRn),
		.USB_CEn(USB_CEn),
		.USB_ALEn(USB_ALEn),
	
		.LED_hbeat(GPIO_LED5),
		.LED_armed(GPIO_LED3),
		.LED_ADCDCMUnlock(GPIO_LED2),
		.LED_CLKGENDCMUnlock(GPIO_LED4),
		.ADC_Data(ADC_Data),
		.ADC_OR(ADC_OR),
		.ADC_clk(ADC_clk),
		.ADC_clk_feedback(ADC_clk_fb),
		.DUT_CLK_i(extclk_mux),
		.DUT_trigger_i(ext_trigger[0]),
		.amp_gain(amp_gain),
		.amp_hilo(amp_hilo),
		.target_clk(clkgen),

		.reg_reset_o(reg_rst),
		.reg_address_o(reg_addr),
		.reg_bytecnt_o(reg_bcnt),
		.reg_datao_o(reg_datao),
		.reg_datai_i( reg_datai_cw | reg_datai_glitch | reg_datai_glitch2 | reg_datai_reconfig | reg_datai_decode | reg_datai_mmctarg | reg_datai_mmctrig | reg_datai_edgetrig | reg_datai_clkdiv),
		.reg_size_o(reg_size),
		.reg_read_o(reg_read),
		.reg_write_o(reg_write),
		.reg_addrvalid_o(reg_addrvalid),
		.reg_stream_i(1'b0),
		.reg_hypaddress_o(reg_hypaddr),
		.reg_hyplen_i(reg_hyplen_cw |  reg_hyplen_glitch | reg_hyplen_glitch2 | reg_hyplen_reconfig | reg_hyplen_decode | reg_hyplen_mmctarg | reg_hyplen_mmctrig | reg_hyplen_edgetrig | reg_hyplen_clkdiv)
	);	

	wire clkgen_div;
		
	reg_clkdiv reg_clkdiv(
		.reset_i(reg_rst),
		.clk(clk_usb_buf),
		.reg_address(reg_addr), 
		.reg_bytecnt(reg_bcnt), 
		.reg_datao(reg_datai_clkdiv), 
		.reg_datai(reg_datao), 
		.reg_size(reg_size), 
		.reg_read(reg_read), 
		.reg_write(reg_write), 
		.reg_addrvalid(reg_addrvalid), 
		.reg_hypaddress(reg_hypaddr), 
		.reg_hyplen(reg_hyplen_clkdiv),
		.reg_stream(),
		.extclk_i(clkgen),
		.divextclk_o(clkgen_div)
		);

	
	wire enable_output_nrst;
	wire output_nrst;
	wire enable_output_pdid;
	wire output_pdid;
	wire enable_output_pdic;
	wire output_pdic;
		
		reg_chipwhisperer reg_chipwhisperer(
		.reset_i(reg_rst),
		.clk(clk_usb_buf),
		.reg_address(reg_addr), 
		.reg_bytecnt(reg_bcnt), 
		.reg_datao(reg_datai_cw), 
		.reg_datai(reg_datao), 
		.reg_size(reg_size), 
		.reg_read(reg_read), 
		.reg_write(reg_write), 
		.reg_addrvalid(reg_addrvalid), 
		.reg_hypaddress(reg_hypaddr), 
		.reg_hyplen(reg_hyplen_cw),
		.reg_stream(),
		//.extclk_fpa_io(),
		//.extclk_fpb_i(1'b0),
		.extclk_pll_i(1'b0),
		.extclk_rearin_i(target_hs1),
		.extclk_rearout_o(target_hs2),
		.extclk_o(extclk_mux),
		.adc_sample_clk(adc_sample_clk),
		//.trigger_fpa_i(),
		//.trigger_fpb_i(),
		.trigger_io1_i(target_io1),
		.trigger_io2_i(target_io2),
		.trigger_io3_i(target_io3),
		.trigger_io4_i(target_io4),
		.trigger_ext_o(advio_trigger_line),
		.trigger_advio_i(1'b0),
		.trigger_anapattern_i(1'b0),
		.trigger_decodedio_i(decode_trigger),
		.trigger_mmc_i(mmc_trigger),
		.trigger_edge_i(edge_trigger),
		.clkgen_i({clkgen_div, clkgen}),
		.glitchclk_i(glitchclk),
		
		.targetio1_io(target_io1),
		.targetio2_io(target_io2),
		.targetio3_io(target_io3),
		.targetio4_io(target_io4),
		
		.hsglitcha_o(glitchout_highpwr),
		.hsglitchb_o(glitchout_lowpwr),
		
		.enable_avrprog(enable_avrprog),
		
		.enable_output_nrst(enable_output_nrst),
	   .output_nrst(output_nrst),
	   .enable_output_pdid(enable_output_pdid),
	   .output_pdid(output_pdid),
	   .enable_output_pdic(enable_output_pdic),
	   .output_pdic(output_pdic),
		
		.uart_tx_i(USB_ser0_tx_i),
		.uart_rx_o(USB_ser0_rx_o),
		.usi_out_i(1'b0),
		.usi_in_o(),
		.targetpower_off(target_npower),
				
		.trigger_o(ext_trigger)
	);
		
	reg_clockglitch reg_clockglitch(
		.reset_i(reg_rst),
		.clk(clk_usb_buf),
		.reg_address(reg_addr), 
		.reg_bytecnt(reg_bcnt), 
		.reg_datao(reg_datai_glitch), 
		.reg_datai(reg_datao), 
		.reg_size(reg_size), 
		.reg_read(reg_read), 
		.reg_write(reg_write), 
		.reg_addrvalid(reg_addrvalid), 
		.reg_hypaddress(reg_hypaddr), 
		.reg_hyplen(reg_hyplen_glitch),
		.reg_stream(),
		.sourceclk0(target_hs1),
		.sourceclk1(clkgen),
		.glitchclk(glitchclk[0]),
		.exttrigger(ext_trigger[0])	
		);
		
	reg_clockglitch #(
		.CLOCKGLITCH_SETTINGS_ADDR(44), // overlap with reg_usi because there's no free address
		.CLOCKGLITCH_OFFSET_ADDR(45), // overlap with reg_usi because there's no free address
		.CLOCKGLITCH_REPEAT_ADDR(46), // overlap with reg_usi because there's no free address
		.GLITCHCYCLES_CNT_ADDR(19), // SHOULD NOT BE USED
		.GLITCH_RECONFIG_RB_ADDR(56), // SHOULD NOT BE USED
		.SUPPORT_CLOCK_GLITCH(0)
	) reg_clockglitch2(
		.reset_i(reg_rst),
		.clk(clk_usb_buf),
		.reg_address(reg_addr), 
		.reg_bytecnt(reg_bcnt), 
		.reg_datao(reg_datai_glitch2), 
		.reg_datai(reg_datao), 
		.reg_size(reg_size), 
		.reg_read(reg_read), 
		.reg_write(reg_write), 
		.reg_addrvalid(reg_addrvalid), 
		.reg_hypaddress(reg_hypaddr), 
		.reg_hyplen(reg_hyplen_glitch2),
		.reg_stream(),
		.sourceclk0(target_hs1),
		.sourceclk1(clkgen),
		.glitchclk(glitchclk[1]),
		.exttrigger(ext_trigger[1])	
		);
	
`ifdef ENABLE_RECONFIG
	reg_reconfig reg_reconfig(
		.reset_i(reg_rst),
		.clk(clk_usb_buf),
		.icap_clk(clk_slow),
		.reg_address(reg_addr), 
		.reg_bytecnt(reg_bcnt), 
		.reg_datao(reg_datai_reconfig), 
		.reg_datai(reg_datao), 
		.reg_size(reg_size), 
		.reg_read(reg_read), 
		.reg_write(reg_write), 
		.reg_addrvalid(reg_addrvalid), 
		.reg_hypaddress(reg_hypaddr), 
		.reg_hyplen(reg_hyplen_reconfig),
		.reg_stream()
		);
`else
	assign reg_hyplen_reconfig = 'd0;
	assign reg_datai_reconfig = 'd0;
`endif

	 wire target_highz = target_npower;
	 	
	 assign target_PDID = (target_highz) ? 1'bZ :
		                   (enable_output_pdid) ? output_pdid :
								 1'bZ;
							
	 assign target_PDIC = (target_highz) ? 1'bZ:
	                      (enable_output_pdic) ? output_pdic :
								 1'bZ;
	                    
	 assign target_nRST = (target_highz) ? 1'bZ :
	                      (enable_avrprog) ? USB_treset_i :
								 (enable_output_nrst) ? output_nrst :
								 1'bZ;
	 assign target_MOSI = (target_highz) ? 1'bZ :
	                      (enable_avrprog) ? USB_spi0_mosi_i : 1'bZ;
	 assign target_SCK = (target_highz) ? 1'bZ :
	                      (enable_avrprog) ? USB_spi0_sck_i : 1'bZ;
	 assign USB_spi0_miso_o = (enable_avrprog) ? target_MISO : ext_miso;	
	 
	 wire sc_enable = 1'b1;
	 
	 assign sc_rst = (sc_enable) ? USB_sc_rst : 1'bZ;
	 assign sc_clk = (sc_enable) ? USB_sc_clk : 1'bZ;
	 assign sc_aux1 = (sc_enable) ? USB_sc_aux1 : 1'bZ;
	 assign sc_aux2 = (sc_enable) ? USB_sc_aux2 : 1'bZ;
	 assign sc_io = (sc_enable) ? ((USB_spi2_txd2) ? 0 : 1'bZ) : 1'bZ;
	 assign USB_spi2_rxd2 = (sc_enable) ? sc_io : 1'bZ;
	 
	 assign ext_sck = USB_spi0_sck_i;
	 assign ext_mosi = USB_spi0_mosi_i;
	 assign lcd_cs = USB_spi0_cs0;
	 assign lcd_dc = USB_spare2;
	 assign avr_cs = USB_spare1; 
			
	/*
	assign ila_trigbus[7:0] = USB_D;
	assign ila_trigbus[15:8] = USB_Addr;
	assign ila_trigbus[16] = USB_RDn;
	assign ila_trigbus[17] = USB_WRn;
	assign ila_trigbus[18] = USB_ALEn;
	assign ila_trigbus[19] = USB_CEn;

	coregen_icon csicon (
    .CONTROL0(cs_control0) // INOUT BUS [35:0]
	);
	
	coregen_ila csila (
    .CONTROL(cs_control0), // INOUT BUS [35:0]
    .CLK(clk_usb), // IN
    .TRIG0(ila_trigbus) // IN BUS [63:0]
	 );
	 */
	
	reg_decodeiotrigger registers_decodetrigger (
		.reset_i(reg_rst),
		.clk(clk_usb_buf),
		.reg_address(reg_addr), 
		.reg_bytecnt(reg_bcnt), 
		.reg_datao(reg_datai_decode), 
		.reg_datai(reg_datao), 
		.reg_size(reg_size), 
		.reg_read(reg_read), 
		.reg_write(reg_write), 
		.reg_addrvalid(reg_addrvalid), 
		.reg_hypaddress(reg_hypaddr), 
		.reg_hyplen(reg_hyplen_decode),
		.reg_stream(),
		
		.ext_iomux(advio_trigger_line),
		.sck(target_SCK),
		.mosi(target_MOSI),
		.miso(target_MISO),
		.pdid_cs(target_PDIC),
		.pdic(),
				
		.trig_out(decode_trigger)
	);
	
	reg_mmctarget registers_mmctarget(
		.reset_i(reg_rst),
		.clk(clk_usb_buf),
		.reg_address(reg_addr), 
		.reg_bytecnt(reg_bcnt), 
		.reg_datao(reg_datai_mmctarg), 
		.reg_datai(reg_datao), 
		.reg_size(reg_size), 
		.reg_read(reg_read), 
		.reg_write(reg_write), 
		.reg_addrvalid(reg_addrvalid), 
		.reg_stream(),
		.reg_hypaddress(reg_hypaddr), 
		.reg_hyplen(reg_hyplen_mmctarg),
		.target_mmc_clk(target_io3),
		.target_mmc_cmd(target_io4)					              
   );
	
	reg_mmctrigger registers_mmctrigger (
		.reset_i(reg_rst),
		.clk(clk_usb_buf),
		.reg_address(reg_addr), 
		.reg_bytecnt(reg_bcnt), 
		.reg_datao(reg_datai_mmctrig), 
		.reg_datai(reg_datao), 
		.reg_size(reg_size), 
		.reg_read(reg_read), 
		.reg_write(reg_write), 
		.reg_addrvalid(reg_addrvalid), 
		.reg_hypaddress(reg_hypaddr), 
		.reg_hyplen(reg_hyplen_mmctrig),
		.reg_stream(),
		
		.target_mmc_clk(target_io3),
		.target_mmc_cmd(target_io4),
				
		.trig_out(mmc_trigger)
	);
	
	reg_edgetrigger registers_edgetrigger (
		.reset_i(reg_rst),
		.clk(clk_usb_buf),
		.reg_address(reg_addr), 
		.reg_bytecnt(reg_bcnt), 
		.reg_datao(reg_datai_edgetrig), 
		.reg_datai(reg_datao), 
		.reg_size(reg_size), 
		.reg_read(reg_read), 
		.reg_write(reg_write), 
		.reg_addrvalid(reg_addrvalid), 
		.reg_hypaddress(reg_hypaddr), 
		.reg_hyplen(reg_hyplen_edgetrig),
		.reg_stream(),
		
		.sources_i({4'b0, target_PDID, target_PDIC, target_nRST, target_MISO, target_MOSI, target_SCK, target_hs2, target_hs1, target_io4, target_io3, target_io2, target_io1}),
				
		.trig_out(edge_trigger)
	);
 		
endmodule
