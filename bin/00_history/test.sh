#!/bin/bash

export x=( "a=\"Ahoj\"" "echo \"\${a}\"" )

echo 1

bash <<EOF
$( for (( i=0 ; i<${#x[@]} ; i++ )) ; do echo ${x[${i}]} ; done )
EOF

echo 2

bash <<EOF
a="Ahoj"
echo "\${a}"
EOF

echo 3

echo "#" > test_inner.sh
for (( i=0 ; i<${#x[@]} ; i++ )) ; do echo ${x[${i}]} >> test_inner.sh ; done
bash test_inner.sh

echo 4
export y=( "a=\"Ahoj\" ;
b=\"Martine\" ;
echo \"\${a}\" \"\${b}\"" )
echo 1:${y[@]}
bash <<EOF
$( for (( i=0 ; i<${#y[@]} ; i++ )) ; do echo ${y[${i}]} ; done )
EOF

