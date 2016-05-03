#!/bin/bash

# With two files having numbers per row, find the union of the files.
echo "Union:"
comm -1 -2 <(sort $1 | uniq) <(sort $2 | uniq) | tee union_a_b.txt
echo "------"

