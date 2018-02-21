#!/bin/bash

################################################################################
#
################################################################################

par_file=${1}
src_file=${2}

echo "" > .${src_file} ; chmod 700 .${src_file}

cat ${par_file}  >> .${src_file}
echo "cat <<EOF" >> .${src_file}
cat ${src_file}  >> .${src_file}
echo "EOF"       >> .${src_file}

./.${src_file}

rm .${src_file}
