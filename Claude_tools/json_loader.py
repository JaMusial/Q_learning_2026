"""
JSON Loader Utility for Q-Learning Debug Logs
=============================================

Common utility module for loading and parsing MATLAB-exported JSON debug logs.

Usage:
    from json_loader import load_debug_json, get_available_logs, LogData

    # Load single file
    data = load_debug_json('logi_training.json')

    # Load all available logs
    logs = get_available_logs()
    for name, data in logs.items():
        print(f"{name}: {len(data.get('Q_e', []))} samples")
"""

import json
import os
from pathlib import Path
from typing import Dict, List, Any, Optional, Union
import numpy as np


# Default paths
DEFAULT_LOG_DIR = Path(__file__).parent.parent
LOG_FILES = {
    'before': 'logi_before_learning.json',
    'training': 'logi_training.json',
    'after': 'logi_after_learning.json'
}

# Key field categories for easier access
DEBUG_FIELDS = [
    'DEBUG_old_state', 'DEBUG_old_action', 'DEBUG_old_R', 'DEBUG_old_uczenie',
    'DEBUG_stan_T0', 'DEBUG_stan_T0_for_bootstrap', 'DEBUG_old_stan_T0',
    'DEBUG_wyb_akcja_T0', 'DEBUG_uczenie_T0', 'DEBUG_R_buffered',
    'DEBUG_Q_old_value', 'DEBUG_Q_new_value', 'DEBUG_bootstrap', 'DEBUG_TD_error',
    'DEBUG_global_max_Q', 'DEBUG_global_max_state', 'DEBUG_global_max_action',
    'DEBUG_goal_Q', 'DEBUG_is_goal_state', 'DEBUG_is_updating_goal'
]

Q_CONTROLLER_FIELDS = [
    'Q_e', 'Q_de', 'Q_de2', 'Q_stan_value', 'Q_stan_nr',
    'Q_akcja_value', 'Q_akcja_value_bez_f_rzutujacej', 'Q_akcja_nr',
    'Q_funkcja_rzut', 'Q_R', 'Q_losowanie', 'Q_y', 'Q_delta_y',
    'Q_u', 'Q_u_increment', 'Q_u_increment_bez_f_rzutujacej',
    'Q_t', 'Q_d', 'Q_SP', 'Q_czas_zaklocenia', 'Q_maxS', 'Q_table_update'
]

PI_CONTROLLER_FIELDS = [
    'PID_e', 'PID_de', 'PID_de2', 'PID_y', 'PID_u', 'PID_delta_y'
]

REF_TRAJECTORY_FIELDS = [
    'Ref_e', 'Ref_y', 'Ref_de', 'Ref_de2', 'Ref_stan_value', 'Ref_stan_nr'
]


class LogData:
    """Container for parsed log data with convenient access methods."""

    def __init__(self, data: Dict[str, Any], filename: str = ""):
        self._data = data
        self.filename = filename
        self._arrays = {}  # Cache for numpy arrays

    def __getitem__(self, key: str) -> Any:
        return self._data.get(key, [])

    def __contains__(self, key: str) -> bool:
        return key in self._data

    def keys(self) -> List[str]:
        return list(self._data.keys())

    def get(self, key: str, default: Any = None) -> Any:
        return self._data.get(key, default)

    def as_array(self, key: str) -> np.ndarray:
        """Get field as numpy array (cached)."""
        if key not in self._arrays:
            self._arrays[key] = np.array(self._data.get(key, []))
        return self._arrays[key]

    @property
    def n_samples(self) -> int:
        """Number of samples in the log."""
        for field in ['Q_e', 'Q_t', 'DEBUG_old_state']:
            if field in self._data and len(self._data[field]) > 0:
                return len(self._data[field])
        return 0

    @property
    def has_debug_data(self) -> bool:
        """Check if debug fields are populated."""
        for field in DEBUG_FIELDS:
            if field in self._data and len(self._data[field]) > 0:
                arr = np.array(self._data[field])
                if np.any(arr != 0):
                    return True
        return False

    def get_debug_fields(self) -> Dict[str, np.ndarray]:
        """Get all DEBUG fields as numpy arrays."""
        return {f: self.as_array(f) for f in DEBUG_FIELDS if f in self._data}

    def get_q_fields(self) -> Dict[str, np.ndarray]:
        """Get all Q controller fields as numpy arrays."""
        return {f: self.as_array(f) for f in Q_CONTROLLER_FIELDS if f in self._data}

    def get_pi_fields(self) -> Dict[str, np.ndarray]:
        """Get all PI controller fields as numpy arrays."""
        return {f: self.as_array(f) for f in PI_CONTROLLER_FIELDS if f in self._data}

    def get_time_range(self) -> tuple:
        """Get (start_time, end_time) from Q_t field."""
        if 'Q_t' in self._data and len(self._data['Q_t']) > 0:
            t = np.array(self._data['Q_t'])
            valid = t[t > 0]  # Filter out zeros
            if len(valid) > 0:
                return float(valid[0]), float(valid[-1])
        return 0.0, 0.0

    def find_learning_samples(self) -> np.ndarray:
        """Find indices where Q-learning update occurred."""
        if 'DEBUG_uczenie_T0' in self._data:
            uczenie = self.as_array('DEBUG_uczenie_T0')
            return np.where(uczenie == 1)[0]
        elif 'Q_losowanie' in self._data:
            # Fallback: exploration flag indicates learning
            los = self.as_array('Q_losowanie')
            return np.where(los >= 0)[0]
        return np.array([])

    def summary(self) -> str:
        """Generate a summary string."""
        lines = [
            f"Log: {self.filename}",
            f"Samples: {self.n_samples:,}",
            f"Debug data: {'Yes' if self.has_debug_data else 'No'}",
            f"Time range: {self.get_time_range()}",
            f"Fields: {len(self._data)} total"
        ]
        return "\n".join(lines)


def load_debug_json(filename: str, log_dir: Optional[Union[str, Path]] = None) -> LogData:
    """
    Load a JSON debug log file.

    Args:
        filename: Name of the JSON file (e.g., 'logi_training.json')
        log_dir: Directory containing log files (default: project root)

    Returns:
        LogData object with parsed data

    Raises:
        FileNotFoundError: If file doesn't exist
        json.JSONDecodeError: If file is not valid JSON
    """
    if log_dir is None:
        log_dir = DEFAULT_LOG_DIR

    filepath = Path(log_dir) / filename

    if not filepath.exists():
        raise FileNotFoundError(f"Log file not found: {filepath}")

    print(f"Loading {filepath.name}...", end=" ")

    with open(filepath, 'r', encoding='utf-8') as f:
        data = json.load(f)

    log_data = LogData(data, filename)
    print(f"OK ({log_data.n_samples:,} samples)")

    return log_data


def get_available_logs(log_dir: Optional[Union[str, Path]] = None) -> Dict[str, LogData]:
    """
    Load all available log files.

    Args:
        log_dir: Directory containing log files (default: project root)

    Returns:
        Dict mapping log names ('before', 'training', 'after') to LogData objects
    """
    if log_dir is None:
        log_dir = DEFAULT_LOG_DIR

    logs = {}
    for name, filename in LOG_FILES.items():
        filepath = Path(log_dir) / filename
        if filepath.exists():
            try:
                logs[name] = load_debug_json(filename, log_dir)
            except Exception as e:
                print(f"Warning: Could not load {filename}: {e}")

    return logs


def find_nonzero_range(arr: np.ndarray) -> tuple:
    """
    Find the range of indices where array has non-zero values.

    Returns:
        (start_idx, end_idx) tuple, or (0, 0) if all zeros
    """
    nonzero = np.where(arr != 0)[0]
    if len(nonzero) == 0:
        return 0, 0
    return int(nonzero[0]), int(nonzero[-1])


def detect_episodes(time_arr: np.ndarray, threshold: float = 1.0) -> List[tuple]:
    """
    Detect episode boundaries from time array (resets indicate new episode).

    Args:
        time_arr: Array of timestamps
        threshold: Time jump threshold to detect reset

    Returns:
        List of (start_idx, end_idx) tuples for each episode
    """
    if len(time_arr) == 0:
        return []

    episodes = []
    start_idx = 0

    for i in range(1, len(time_arr)):
        # Detect time reset (new episode starts)
        if time_arr[i] < time_arr[i-1] - threshold:
            episodes.append((start_idx, i-1))
            start_idx = i

    # Add final episode
    episodes.append((start_idx, len(time_arr)-1))

    return episodes


def get_goal_state_info(data: LogData) -> Dict[str, Any]:
    """
    Extract goal state information from log data.

    Returns:
        Dict with goal state number, action number, and related statistics
    """
    info = {}

    # Goal state/action are typically at index 50 (1-indexed in MATLAB = 51)
    # But we should detect from data
    if 'DEBUG_global_max_state' in data:
        max_states = data.as_array('DEBUG_global_max_state')
        valid = max_states[max_states > 0]
        if len(valid) > 0:
            # Most common max state should be goal state
            from collections import Counter
            counts = Counter(valid.astype(int))
            info['goal_state'] = counts.most_common(1)[0][0]

    if 'DEBUG_global_max_action' in data:
        max_actions = data.as_array('DEBUG_global_max_action')
        valid = max_actions[max_actions > 0]
        if len(valid) > 0:
            from collections import Counter
            counts = Counter(valid.astype(int))
            info['goal_action'] = counts.most_common(1)[0][0]

    if 'DEBUG_goal_Q' in data:
        goal_q = data.as_array('DEBUG_goal_Q')
        valid = goal_q[goal_q > 0]
        if len(valid) > 0:
            info['goal_q_final'] = float(valid[-1])
            info['goal_q_max'] = float(np.max(valid))
            info['goal_q_min'] = float(np.min(valid))

    return info


if __name__ == "__main__":
    # Test the loader
    print("=" * 60)
    print("Q-Learning Debug Log Loader - Test")
    print("=" * 60)

    logs = get_available_logs()

    if not logs:
        print("No log files found!")
    else:
        for name, data in logs.items():
            print(f"\n{name.upper()}")
            print("-" * 40)
            print(data.summary())

            if data.has_debug_data:
                goal_info = get_goal_state_info(data)
                print(f"Goal state info: {goal_info}")
