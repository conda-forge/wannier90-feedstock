#!/usr/bin/env bash

set -euxo pipefail

cp "${RECIPE_DIR}/make.inc" "${SRC_DIR}/make.inc"
cd "${SRC_DIR}"

# During an OpenMPI cross-build, mpif90 must be executable on the build
# platform, while resolving headers and libraries from the host prefix.
if [[ "${CONDA_BUILD_CROSS_COMPILATION:-0}" == "1" ]]; then
  export OPAL_PREFIX="${PREFIX}"
  MPIF90="${BUILD_PREFIX}/bin/mpif90"
else
  MPIF90="${PREFIX}/bin/mpif90"
fi

cat >> make.inc <<EOF

COMMS = mpi
MPIF90 = ${MPIF90}
EOF

# Wannier90's MPI wrapper routines may trigger strict argument-mismatch errors
# with modern gfortran.
if [[ "${FC:-}" == *gfortran* ]] &&
   ! grep -q -- '-fallow-argument-mismatch' make.inc; then
  sed 's|^FCOPTS = .*|& -fallow-argument-mismatch|' \
    make.inc > make.inc.tmp
  mv make.inc.tmp make.inc
fi

echo "===== Effective make.inc ====="
cat make.inc
echo "=============================="
echo "MPIF90=${MPIF90}"

sed \
  -e '/^wannier90_proj_auto_wout:/,/^[^[:space:]]/s/^    omegaD:.*/    omegaD: {abs: 1.1e-6, rel: 6.0e-6}/' \
  -e '/^wannier90_slwfc_wout:/,/^[^[:space:]]/s/^    final_spreads:.*/    final_spreads: {abs: 4.0e-6, rel: 4.0e-6}/' \
  -e '/^wannier90_slwfc_wout:/,/^[^[:space:]]/s/^    omegaRest:.*/    omegaRest: {abs: 1.1e-5, rel: 1.1e-5}/' \
  test-suite/profiles.yaml > test-suite/profiles.yaml.tmp
mv test-suite/profiles.yaml.tmp test-suite/profiles.yaml

make wannier -j "${CPU_COUNT:-1}"

if [[ "${CONDA_BUILD_CROSS_COMPILATION:-0}" != "1" ||
      -n "${CROSSCOMPILING_EMULATOR:-}" ]]; then
  make test-serial -j "${CPU_COUNT:-1}"
fi

make install PREFIX="${PREFIX}"
