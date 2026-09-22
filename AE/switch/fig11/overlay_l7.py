from netaddr import IPAddress
# L7 experiments: every new connection to the frontend address must reach the
# frontend proxy app on node8; migration bindings then redirect per connection.
p4 = bfrt.capybara_switch_fe_fig11.pipe
for i in range(16):
    p4.Ingress.backend_mac_hi32.mod(REGISTER_INDEX=i, f1=0x08c0ebb6)
    p4.Ingress.backend_mac_lo16.mod(REGISTER_INDEX=i, f1=0xe805)
    p4.Ingress.backend_ip.mod(REGISTER_INDEX=i, f1=IPAddress("10.0.1.8"))
    p4.Ingress.backend_port.mod(REGISTER_INDEX=i, f1=10000)
bfrt.complete_operations()
print("L7_OVERLAY_DONE")
