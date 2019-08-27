
# Performance

*Somewhere to keep track of performance over time.*

---

## Baseline

- No Branch Prediction
  - 4 cycle control flow change penalty.
- No Stalling
- 2 cycle memory latency. Due to bug in testbench.


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

Average IPC: 0.371

## Improvement 1: Testbench bug fixed and trivial branching.

- No Branch Prediction
  - 4 cycle conditional control flow change penalty.
  - 1 cycle PC relative jump penalty.
- No Stalling
- 1 cycle memory latency.


Benchmark      | Cycles      | Instructions | IPC
---------------|-------------|--------------|------------------------
sglib-combined | 6107910     | 2827973      | 0.46
matmult-int    | 19105311    | 3248422      | 0.17
cubic          | 10900397    | 3376386      | 0.31
statemate      | 4998730     | 3443477      | 0.69
crc32          | 10993817    | 3567034      | 0.32
slre           | 5658098     | 3242167      | 0.57
minver         | 6980493     | 2968638      | 0.43
aha-mont64     | 7145155     | 3385085      | 0.47
nsichneu       | 6807749     | 2391220      | 0.35
huffbench      | 5427198     | 2692430      | 0.50
st             | 9193981     | 3284773      | 0.36
edn            | 5823557     | 3153928      | 0.14
nettle-aes     | 4254781     | 3760611      | 0.88
wikisort       | 6799600     | 2462599      | 0.36
nettle-sha256  | 3737824     | 3392801      | 0.91
qrduino        | 9274650     | 3443724      | 0.37
picojpeg       | 7888266     | 3126586      | 0.40
ud             | 8775738     | 2652126      | 0.30
nbody          | 8573359     | 3085161      | 0.36

Average IPC: 0.440

## Improvement 2: Simple "If backwards, predict taken"

- Static Branch Prediction
  - 4 cycle conditional control flow change penalty.
  - Always predict taken if the branch is backwards.
    - 1 cycle penalty for correct prediction
    - 4 cycle penalty for incorrect prediction
  - 1 cycle PC relative jump penalty.
- No Stalling
- 1 cycle memory latency.


Benchmark      | Cycles      | Instructions | IPC
---------------|-------------|--------------|------------------------
sglib-combined | 5988998     | 2827973      | 0.47
matmult-int    | 18049710    | 3248422      | 0.18
cubic          | 10907163    | 3376386      | 0.31
statemate      | 4919287     | 3443477      | 0.70
crc32          | 10548830    | 3567034      | 0.34
slre           | 5701478     | 3242167      | 0.57
minver         | 7102573     | 2968638      | 0.42
aha-mont64     | 5384423     | 3385085      | 0.63
nsichneu       | 6832776     | 2391220      | 0.35
huffbench      | 4754929     | 2692430      | 0.57
st             | 9199553     | 3284773      | 0.36
edn            | 21658769    | 3153928      | 0.15
nettle-aes     | 4209791     | 3760611      | 0.89
wikisort       | 6767437     | 2462599      | 0.36
nettle-sha256  | 3657250     | 3392801      | 0.93
qrduino        | 9045320     | 3443724      | 0.38
picojpeg       | 7515370     | 3126586      | 0.42
ud             | 8683010     | 2652126      | 0.31
nbody          | 8555956     | 3085161      | 0.36

Average IPC: 0.457
