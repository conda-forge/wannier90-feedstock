#!/bin/bash
cp ${RECIPE_DIR}/make.inc ${SRC_DIR}/make.inc
make wannier -j$CPU_COUNT
if [[ "${CONDA_BUILD_CROSS_COMPILATION:-0}" != "1" ]]; then
  make test-serial -j$CPU_COUNT
fi
make install PREFIX=${PREFIX}
