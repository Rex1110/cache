# L1 Data Cache

This project implements and verifies an L1 data cache module. Key features include:

## ✅ Cache Design
- **Access Types**: Supports byte, halfword, and word operations.
- **Structure**: Direct-mapped cache with 64 lines, each line being 128 bits wide.

## 🎯 Hit/Miss Behavior
- **Cache Hit**:
  - Occurs when the valid bit is set and the tag matches the requested address.
  - For read hit, data is returned directly from the cache.
  - For write hit, the cache is updated with the new data.
- **Cache Miss**:
  - Happens when the cache line is invalid or the tag mismatches.
  - For read miss, the cache performs a read allocate — it refills the cache line from memory.
  - For write miss, the cache follows a write-around policy — data is written directly to memory without updating the cache.

## 🧪 Testbench Verification
- Simulates a range of operations: sequential reads/writes and randomized accesses.
- Validates cache correctness using a shadow memory model.
- **Assertions**:
  - Verify that the valid bits are reset correctly after reset.
  - Check read hit occurs when the tag matches and valid bit is set.
  - Check write hit occurs when the tag matches and valid bit is set.
