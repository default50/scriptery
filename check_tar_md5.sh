#! /bin/bash

# This script was found on this XDA post http://forum.xda-developers.com/showpost.php?p=46563602&postcount=1
# The poster thanked this StackOverflow post http://stackoverflow.com/a/9255420/1943898
# Credits to them

check_tar_md5 () {
    local file="${1:?Required: file to check}"
    [[ ! -f "$file" ]] && {
            echo "File not found: $file" >&2
            return 1
    }
    local filename="$(basename "$file")"
    if [ "${filename##*.}" = md5 ]; then filename="${filename%.*}"; fi;
    local md5_line_length=$(printf "%032d *%s\n" 0 "$filename" | wc -c)
    local embedded_md5=$(tail -c $md5_line_length "$file" | tr [A-Z] [a-z] | ( read md5 rest; echo $md5 ) )
    local actual_md5=$(head -c -$md5_line_length "$file" | md5sum | ( read md5 rest; echo $md5 ) )
    echo "Embedded md5: " $embedded_md5
    echo "Actual   md5: " $actual_md5
    if [ $embedded_md5 = $actual_md5 ]; then
            echo "$file: OK"
    else
            echo "$file: FAILED"
            return 1
    fi
}

[[ ! -z "$1" ]] && check_tar_md5 "$1"
