import sys
port = bfrt.port.port
for dp in [16, 20, 24, 28, 32, 36]:
    try:
        port.add(DEV_PORT=dp, PORT_ENABLE=True, SPEED="BF_SPEED_100G", FEC="BF_FEC_TYP_NONE", AUTO_NEGOTIATION="PM_AN_FORCE_DISABLE")
        print("added port", dp); sys.stdout.flush()
    except Exception as e:
        print("port", dp, "err:", e); sys.stdout.flush()
bfrt.complete_operations()
print("PORTADD_DONE"); sys.stdout.flush()
