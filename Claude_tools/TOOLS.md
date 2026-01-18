# Q-Learning Debug Analysis Tools

Python tools for analyzing Q-learning debug logs exported from MATLAB.

**Created**: 2026-01-15
**Purpose**: Help diagnose Q-learning issues by analyzing JSON debug logs

## Prerequisites

1. **Enable debug logging in MATLAB** before running experiments:
   ```matlab
   % In config.m, set:
   debug_logging = 1;
   ```

2. **Run MATLAB experiment** (`main.m`) - this generates:
   - `logi_before_learning.json` - verification before training
   - `logi_training.json` - training phase data
   - `logi_after_learning.json` - verification after training

3. **Required Python packages** (all pre-installed):
   - numpy, json (standard library)

## Quick Start

```bash
cd Claude_tools

# Run full diagnostic (RECOMMENDED - start here)
python summary_report.py

# Compare before vs after learning
python compare_logs.py

# Run specific analyzer
python q_convergence_analyzer.py logi_training.json
```

## Tools Overview

### 1. summary_report.py (Main Entry Point)

**Purpose**: Runs ALL analyzers and generates unified diagnostic report.

**Usage**:
```bash
python summary_report.py                    # Analyze all available logs
python summary_report.py logi_training.json # Analyze specific file
python summary_report.py -v                 # Verbose mode (show all output)
```

**Output**:
- Error/Warning/Info counts
- Key metrics summary
- Prioritized recommendations
- Bug-specific guidance

---

### 2. q_convergence_analyzer.py

**Purpose**: Analyze Q-learning convergence metrics.

**Detects**:
- TD error trends (should decrease over time)
- Q(goal,goal) convergence toward 100
- Bootstrap term bounds
- Q-update magnitude trends

**Key Metrics**:
| Metric | Good Value | Bad Sign |
|--------|------------|----------|
| TD error trend | Decreasing | Increasing/oscillating |
| Q(goal,goal) | ~100 | < 50 |
| Bootstrap max | ~99 | > 105 |

**Usage**:
```bash
python q_convergence_analyzer.py
python q_convergence_analyzer.py logi_training.json
```

---

### 3. temporal_checker.py

**Purpose**: Detect state-action-reward temporal mismatches.

**Detects Bugs**:
- **Bug #3**: State-action pairing mismatch
- **Bug #4**: Reward timing mismatch

**What it checks**:
- State pairing: `old_stan_T0` should match expected buffered state
- Action pairing: `wyb_akcja_T0` should match action that caused transition
- Reward timing: R=1 when ARRIVING at goal, not leaving

**Usage**:
```bash
python temporal_checker.py
python temporal_checker.py logi_training.json
```

---

### 4. goal_state_analyzer.py

**Purpose**: Analyze goal state behavior and Q(goal,goal) evolution.

**Detects Bugs**:
- **Bug #5**: Bootstrap contamination (Q(goal,goal) decreases)

**What it checks**:
- Q(goal,goal) monotonically increasing toward 100
- Goal→Goal transitions use bootstrap override
- Goal state visitation frequency
- Reward collection at goal state

**Key Insight**: If Q(goal,goal) DECREASES, Bug #5 is present.

**Usage**:
```bash
python goal_state_analyzer.py
python goal_state_analyzer.py logi_after_learning.json
```

---

### 5. constraint_checker.py

**Purpose**: Detect same-side constraint violations in exploration.

**Detects Bugs**:
- **Bug #6**: Same-side constraint disabled

**Constraint Rule**:
```
State > goal → Action > goal (positive error → increase control)
State < goal → Action < goal (negative error → decrease control)
```

**What it checks**:
- Constraint violations during exploration
- Constraint violations during exploitation (indicates corrupted Q-table)
- Oscillation patterns around goal

**Usage**:
```bash
python constraint_checker.py
python constraint_checker.py logi_training.json
```

---

### 6. projection_analyzer.py

**Purpose**: Analyze projection function behavior.

**Detects Bugs**:
- **Bug #10**: Projection disabled at goal state

**What it checks**:
- Projection application rate
- On-trajectory problem (state≈0 with large error)
- Q vs PI control signal correlation
- Te/Ti relationship estimation

**Note**: If `f_rzutujaca_on=0` (staged learning), projection will be all zeros - this is expected and recommended.

**Usage**:
```bash
python projection_analyzer.py
python projection_analyzer.py logi_after_learning.json
```

---

### 7. compare_logs.py

**Purpose**: Compare before and after learning performance.

**Compares**:
- Error metrics (MAE, RMS, max error)
- Control effort and smoothness
- Goal region visitation
- Q(goal,goal) improvement

**Also compares**: Q controller vs PI controller within same log.

**Usage**:
```bash
python compare_logs.py                              # Use default before/after
python compare_logs.py before.json after.json      # Specify files
```

---

### 8. json_loader.py (Utility Module)

**Purpose**: Common utility for loading and parsing JSON logs.

**Usage in Python**:
```python
from json_loader import load_debug_json, get_available_logs, LogData

# Load single file
data = load_debug_json('logi_training.json')
print(f"Samples: {data.n_samples}")
print(f"Has debug: {data.has_debug_data}")

# Access arrays
error = data.as_array('Q_e')
goal_q = data.as_array('DEBUG_goal_Q')

# Load all available logs
logs = get_available_logs()
for name, log_data in logs.items():
    print(f"{name}: {log_data.n_samples} samples")
```

**LogData methods**:
- `data.as_array(field)` - Get field as numpy array
- `data.n_samples` - Number of samples
- `data.has_debug_data` - Check if DEBUG fields populated
- `data.get_debug_fields()` - Get all DEBUG fields as dict
- `data.summary()` - Get summary string

## Debug Fields Reference

Fields logged when `debug_logging=1`:

### Previous Iteration
| Field | Description |
|-------|-------------|
| `DEBUG_old_state` | State from previous iteration |
| `DEBUG_old_action` | Action from previous iteration |
| `DEBUG_old_R` | Reward from previous iteration |
| `DEBUG_old_uczenie` | Learning flag from previous iteration |

### Dead-Time Compensation (T0_controller > 0)
| Field | Description |
|-------|-------------|
| `DEBUG_stan_T0` | Next state for Q-update (actual) |
| `DEBUG_stan_T0_for_bootstrap` | Next state for bootstrap (override for goal→goal) |
| `DEBUG_old_stan_T0` | State being updated (buffered) |
| `DEBUG_wyb_akcja_T0` | Action being updated (buffered) |
| `DEBUG_uczenie_T0` | Learning flag for update |

### Q-Value Updates
| Field | Description |
|-------|-------------|
| `DEBUG_R_buffered` | Reward used in Q-update |
| `DEBUG_Q_old_value` | Q-value before update |
| `DEBUG_Q_new_value` | Q-value after update |
| `DEBUG_bootstrap` | Bootstrap term: γ·max(Q(s',:)) |
| `DEBUG_TD_error` | TD error: R + γ·max(Q(s',:)) - Q(s,a) |

### Global Q-Table Statistics
| Field | Description |
|-------|-------------|
| `DEBUG_global_max_Q` | Maximum Q-value in entire table |
| `DEBUG_global_max_state` | State with maximum Q |
| `DEBUG_global_max_action` | Action with maximum Q |

### Goal State Tracking
| Field | Description |
|-------|-------------|
| `DEBUG_goal_Q` | Current Q(goal_state, goal_action) |
| `DEBUG_is_goal_state` | 1 if current state = goal |
| `DEBUG_is_updating_goal` | 1 if updating goal state Q-value |

## Bug Detection Mapping

| Bug | Tool | Key Indicator |
|-----|------|---------------|
| #3 State-Action Mismatch | `temporal_checker.py` | State/action pairing rate < 99% |
| #4 Reward Mismatch | `temporal_checker.py` | R=1 not aligned with goal arrivals |
| #5 Bootstrap Contamination | `goal_state_analyzer.py` | Q(goal,goal) decreases |
| #6 Same-Side Constraint | `constraint_checker.py` | Violation rate > 0% |
| #10 Projection Disabled | `projection_analyzer.py` | Projection missing at goal with large error |

## Troubleshooting

### "No debug data found"
- Ensure `debug_logging = 1` in `config.m`
- Re-run MATLAB experiment
- Check that JSON files are in project root

### "Training log empty (0 samples)"
- Training phase may have been skipped
- Check `poj_iteracja_uczenia` setting
- Verify `max_epoki > 0`

### "File not found"
- Run from `Claude_tools` directory
- Or specify full path to JSON file

### Low Q(goal,goal) value
1. Check Bug #5 (bootstrap contamination)
2. Verify reward timing (Bug #4)
3. Check constraint violations (Bug #6)
4. Increase training epochs

## Example Workflow

1. **Run experiment in MATLAB**:
   ```matlab
   % config.m: debug_logging = 1
   main
   ```

2. **Run full diagnostic**:
   ```bash
   cd Claude_tools
   python summary_report.py
   ```

3. **Review errors/warnings**, then run specific analyzer for details:
   ```bash
   python goal_state_analyzer.py    # If Q-value issues
   python constraint_checker.py     # If constraint violations
   python temporal_checker.py       # If temporal mismatch suspected
   ```

4. **Compare before/after**:
   ```bash
   python compare_logs.py
   ```

5. **Fix issues in MATLAB code** based on recommendations

6. **Re-run experiment and verify**

## File Sizes (typical)

| File | Size | Notes |
|------|------|-------|
| `logi_before_learning.json` | ~4 MB | Verification phase |
| `logi_training.json` | ~1-600 MB | Depends on epochs |
| `logi_after_learning.json` | ~4 MB | Verification phase |

Large training logs (>100 MB) may take a few seconds to load.
