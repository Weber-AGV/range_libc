#!/bin/bash
# Fix and build range_libc with CUDA for Jetson Orin (sm_87)
# Run from: ~/f1tenth_ws/src/range_libc/pywrapper/

set -e

if [ ! -f "setup.py" ]; then
    echo "ERROR: Run this script from range_libc/pywrapper/"
    echo "  cd ~/f1tenth_ws/src/range_libc/pywrapper && bash fix_range_libc.sh"
    exit 1
fi

echo "Patching setup.py..."

# 1. Remove -march=native (nvcc doesn't support it)
sed -i 's/"-march=native", //' setup.py

# 2. Remove bogus gcc-8 flags (gcc-8 is not installed on these systems)
sed -i '/gcc-8\|g++-8/d' setup.py

# 3. Update CUDA arch from sm_62 (TX2) to sm_87 (Orin NX / Orin Nano)
sed -i 's/-arch=sm_62/-arch=sm_87/' setup.py

# 4. Fix _compile so non-.cu files are explicitly routed to gcc (not nvcc)
python3 - <<'PYEOF'
with open('setup.py', 'r') as f:
    content = f.read()

old = (
    "        else:\n"
    "            postargs = extra_postargs['gcc']\n"
    "        # postargs = extra_postargs#['gcc']\n"
    "\n"
    "        super(obj, src, ext, cc_args, postargs, pp_opts)\n"
    "        # reset the default compiler_so, which we might have changed for cuda\n"
    "        self.compiler_so = default_compiler_so"
)
new = (
    "        else:\n"
    "            # explicitly reset to gcc for all non-.cu files\n"
    "            self.set_executable('compiler_so', default_compiler_so)\n"
    "            postargs = extra_postargs['gcc']\n"
    "\n"
    "        super(obj, src, ext, cc_args, postargs, pp_opts)\n"
    "        # reset the default compiler_so, which we might have changed for cuda\n"
    "        self.set_executable('compiler_so', default_compiler_so)"
)

if old in content:
    content = content.replace(old, new)
    with open('setup.py', 'w') as f:
        f.write(content)
    print("  [OK] Fixed _compile compiler routing")
elif "set_executable('compiler_so', default_compiler_so)" in content:
    print("  [SKIP] _compile routing already fixed")
else:
    print("  [WARN] Could not match _compile pattern - check setup.py manually")
PYEOF

echo "Building with CUDA (this takes a minute)..."
sudo rm -rf build/
sudo env WITH_CUDA=ON python3 setup.py install

echo "Done! range_libc installed with CUDA support."
