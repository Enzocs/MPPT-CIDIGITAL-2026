bind pwm_generator pwm_generator_monitor 
#(.width(width))
monitor (.clk(clk, .rst(rst), .D_in(D_in, .pwm_out(pwm_out));
