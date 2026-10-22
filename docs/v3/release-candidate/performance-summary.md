## Performance summary
- Cold start (RC AVD, clean): 0.87s (TotalTime 866)
- Hot resume: 0.13s (TotalTime 132)
- Cold start worst case (host thrashed, C6): 15.2s; warm cache: 4.7s
- Warm start (host contended, C6): 4.05s
- Save to Photos (render PNG + MediaStore): 3.4s (C6 stopwatch)
- 4-shot sequence at 3s countdown -> Review: ~25-27s (by design)
- Memory after heavy editing/export: TOTAL PSS 253 MB (Native heap 45.5 MB, no swap)
- dumpsys gfxinfo: unusable on this Flutter/Impeller build (honest limitation)
