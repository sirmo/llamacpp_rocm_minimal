#!/usr/bin/env python3
"""
Filter strace output to find all files accessed by llama-server.
Extracts file paths from openat, open, stat, access syscalls.
"""

import sys
import re
from pathlib import Path

def extract_file_paths(strace_output):
    """Extract unique file paths from strace output."""
    files = set()
    
    # Patterns to match file operations
    patterns = [
        r'openat\([^,]+,\s*"([^"]+)"',  # openat(AT_FDCWD, "/path/to/file", ...)
        r'open\("([^"]+)"',              # open("/path/to/file", ...)
        r'stat\("([^"]+)"',              # stat("/path/to/file", ...)
        r'lstat\("([^"]+)"',             # lstat("/path/to/file", ...)
        r'access\("([^"]+)"',            # access("/path/to/file", ...)
        r'readlink\("([^"]+)"',          # readlink("/path/to/file", ...)
    ]
    
    for line in strace_output.splitlines():
        for pattern in patterns:
            matches = re.findall(pattern, line)
            for match in matches:
                # Skip special files
                if match.startswith('/dev/') or match.startswith('/proc/') or match.startswith('/sys/'):
                    continue
                files.add(match)
    
    return sorted(files)

def categorize_files(files):
    """Categorize files by directory."""
    categories = {
        'rocm_lib': [],
        'rocm_share': [],
        'rocm_other': [],
        'llama_server': [],
        'system_lib': [],
        'other': []
    }
    
    for f in files:
        if '/opt/rocm/lib' in f:
            categories['rocm_lib'].append(f)
        elif '/opt/rocm/share' in f:
            categories['rocm_share'].append(f)
        elif '/opt/rocm' in f:
            categories['rocm_other'].append(f)
        elif 'llama-server' in f or '/llama.cpp/' in f:
            categories['llama_server'].append(f)
        elif f.startswith('/lib') or f.startswith('/usr/lib'):
            categories['system_lib'].append(f)
        else:
            categories['other'].append(f)
    
    return categories

def main():
    if len(sys.argv) > 1:
        with open(sys.argv[1], 'r') as f:
            strace_output = f.read()
    else:
        strace_output = sys.stdin.read()
    
    files = extract_file_paths(strace_output)
    categories = categorize_files(files)
    
    print("=" * 80)
    print("FILES ACCESSED BY llama-server")
    print("=" * 80)
    
    for category, file_list in categories.items():
        if file_list:
            print(f"\n{category.upper().replace('_', ' ')} ({len(file_list)} files):")
            print("-" * 80)
            for f in file_list:
                # Check if file exists and get size
                try:
                    size = Path(f).stat().st_size
                    size_mb = size / (1024 * 1024)
                    if size_mb > 1:
                        print(f"  {f} ({size_mb:.1f} MB)")
                    else:
                        print(f"  {f}")
                except:
                    print(f"  {f} (not found)")
    
    print("\n" + "=" * 80)
    print(f"TOTAL FILES: {len(files)}")
    print("=" * 80)

if __name__ == "__main__":
    main()
