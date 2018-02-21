#!/bin/bash

recursive_function () {
    echo ${1}
    echo ${2}
}

declare -A x
x=( [one]=1 [two]=2 [three]=3 )
echo ${!x[@]}
echo ${x[@]}
recursive_function "${!x[@]}" "${x[@]}"

