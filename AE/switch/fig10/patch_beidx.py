p4 = bfrt.main_eval_fig10.pipe
for p in range(5400, 6100):
    p4.Ingress.reg_be_idx.mod(REGISTER_INDEX=p, f1 = p % 12)
bfrt.complete_operations()
print("BEIDX_PATCHED")
