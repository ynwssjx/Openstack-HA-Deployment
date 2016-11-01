#!/bin/bash

file=$1;section=$2;var=$3
var_value=`awk -F '=' '/\['$section'\]/{a=1}a==1&&$1~/^'$var'/{print $2;exit}' $file`
echo $var_value