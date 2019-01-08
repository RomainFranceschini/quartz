#!/bin/sh

set -e

EXAMPLES_DIR="examples"
BENCHMARKS_DIR="build"
BINARIES_DIR="build"

if [ ! -d "${BINARIES_DIR}" ]
then
  echo "Binaries not found in ${BINARIES_DIR}"
  exit 1
fi

binaries=$(basename $(git ls-files "${EXAMPLES_DIR}/*.cr") | sed "s/\\.cr\$//")
num_binaries=$(printf "%d" "$(echo "${binaries}" | wc -w)")

printf "running %d examples\n" ${num_binaries}

num_ok=0
num_failed=0
result="ok"

for binary in ${binaries}
do
  printf "example ${binary} ..."
  output_file=${binary}_output
  if (${BINARIES_DIR}/${binary} > "${output_file}")
  then
    printf "ok\n"
    num_ok=$((${num_ok} + 1))
  else
    printf "output:\n"
    cat "${output_file}"
    num_failed=$((${num_failed} + 1))
    result="failed"
  fi
  rm -f "${output_file}"
done

printf "\nexample result: ${result}. ${num_ok} passed; ${num_failed} failed\n\n"
exit ${num_failed}
