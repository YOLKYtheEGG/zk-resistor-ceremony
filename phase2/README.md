# Phase 2 - Circuit-specific setup

The Groth16 phase-2 keys for `insert` and `withdraw`. One pair per slot:

```
insert_0000_initial.zkey   withdraw_0000_initial.zkey         coordinator, groth16 setup
insert_0001_<name>.zkey    withdraw_0001_<name>.zkey          contributor
...
insert_<NNNN>_drand-beacon.zkey   withdraw_<NNNN>_drand-beacon.zkey   coordinator
```

Both circuits advance together in one slot. The highest-numbered pair is the current head. Files are around 15 MB (insert) and 8 MB (withdraw).

Phase 2 starts only after phase 1 has closed and the coordinator has run `groth16 setup` for slot 0.
