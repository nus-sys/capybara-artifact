p4 = bfrt.capybara_switch_fe_fig11.pipe
p4.Egress.reg_min_rps_server_port.mod(REGISTER_INDEX=0, f1=10000)
bfrt.complete_operations()
print("MINPORT_DONE")
