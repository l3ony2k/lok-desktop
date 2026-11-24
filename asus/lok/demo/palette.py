import sys
cols=["#f2f2f2","#d9d9d9","#a6a6a6","#737373","#404040","#1f1f1f","#e8590c","#2f9e44","#1c7ed6","#ae3ec9","#f08c00","#0ca678"]
def blk(h,w=10):
    r,g,b=int(h[1:3],16),int(h[3:5],16),int(h[5:7],16); return f"\x1b[48;2;{r};{g};{b}m"+" "*w+"\x1b[0m"
print("\n  lok palette\n")
for row in range(0,12,4):
    for _ in range(3): print("  "+"  ".join(blk(c) for c in cols[row:row+4]))
    print("  "+"  ".join(f"{c:<10}" for c in cols[row:row+4])+"\n")
