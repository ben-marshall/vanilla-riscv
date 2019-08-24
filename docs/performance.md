
# Performance

*Somewhere to keep track of performance over time.*

---

## Baseline

- No Branch Prediction
  - 4 cycle control flow change penalty.
- No Stalling
- Single cycle memory latency.


Benchmark      | Cycles      | Instructions | IPC
---------------|-------------|--------------|------------------------
sglib-combined | 7697568     | 2827973      | 0.37
matmult-int    | 20715666    | 3248422      | 0.16
cubic          | 11890718    | 3376386      | 0.28
statemate      | 7114009     | 3443477      | 0.48
crc32          | 12184144    | 3567034      | 0.29
slre           | 7302183     | 3242167      | 0.44
minver         | 8065262     | 2968638      | 0.37
aha-mont64     | 7556951     | 3385085      | 0.45
nsichneu       | 9377919     | 2391220      | 0.25
huffbench      | 6466035     | 2692430      | 0.42
st             | 10053904    | 3284773      | 0.33
edn            | 23578260    | 3153928      | 0.13
nettle-aes     | 5260271     | 3760611      | 0.71
wikisort       | 7784267     | 2462599      | 0.32
nettle-sha256  | 4470315     | 3392801      | 0.76
qrduino        | 10360252    | 3443724      | 0.33
picojpeg       | 9099066     | 3126586      | 0.34
ud             | 9825338     | 2652126      | 0.27
nbody          | 9295269     | 3085161      | 0.33

Average IPC: 0.37

