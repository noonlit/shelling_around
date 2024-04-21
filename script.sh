#!/bin/bash

# Write a shell script that receives as command line arguments of the type usernames, files, directories and numbers,
# and processes each argument such that:
# - for each username calculates the number of logins on Mondays, printing a list of usernames and corresponding numbers
# (of logins on Mondays) in reverse order of number of logins. Check if the username exists.
# - counts the total number of files and prints this number and the total size occupied by these files.
# - counts the number of directories and prints this number, also the names of directories with execution permissions.
# - each valid number is added in the file mynumbers.txt on a separate line. The file must be sorted numerically decreasingly.
# - anything else is ignored.

# Output example
# John 7 logins
# Lily 4 logins
# Mary 1 logins
# 2 files of size 26k
# 4 directories of which dir1, dir2 have execution permissions

# mynumbers.txt
# 20
# 18
# 4
# 1

############################################################################################################################
# SETUP
############################################################################################################################
# We will used named (not positional) arguments, such as --usernames=mary,john
usernames=""
files=""
directories=""
numbers=""

# Parse arguments into variables.
for arg in "$@"; do
    if [[ $arg == --* ]]; then
        name="${arg%=*}"
        name="${name#--}"
        value="${arg#*=}"

        case "$name" in
            usernames) usernames="$value" ;;
            files) files="$value" ;;
            directories) directories="$value" ;;
            numbers) numbers="$value" ;;
            *) echo "Unknown argument: $name" ;;
        esac
    fi
done

# Debug: print the parsed input
echo "----------------------"
echo "Usernames: $usernames"
echo "Files: $files"
echo "Directories: $directories"
echo "Numbers: $numbers"
echo "----------------------"

# Parse the (hopefully comma-separated) arguments into arrays
OLD_IFS=$IFS
IFS=','

read -ra usernames_array <<< "$usernames"
read -ra files_array <<< "$files"
read -ra directories_array <<< "$directories"
read -ra numbers_array <<< "$numbers"

IFS=$OLD_IFS

###########################################################################################################################
# SOLUTIONS
###########################################################################################################################

# REQ #1: Count the number of logins on Monday for each user.

# We're using the `last` command because this was probably what was intended, since its output contains the day of the week.
# However, the wtmp file used by this utility rotates and it won't reflect the entire history of user logins.

# In theory, we should be using /var/log/auth.log with the "Accepted" pattern,
# or maybe the "systemd-logind.*New session" pattern (though not every new session is a login),
# but this file doesn't store the day of the week and it would be a pain to figure it out from the date.

# If the user exists, we take the output of the `last` command and pipe it to the `sort` command.
# It will be sorted numerically, in reverse order, and by the second field, using ":" as delimiter.
for user in "${usernames_array[@]}"; do
  if grep -q "^$user:" /etc/passwd; then
    count=$(last | grep "$user" | grep -c "Mon")
    echo "$user: $count logins"
  fi
done | sort -t ":" -nrk 2

# Also output the limitations of `last`
last_output=$(last | grep "wtmp begins")
echo "Caution: $last_output. The logins counted are all after that date."

###########################################################################################################################
# REQ #2: Count the total number of files and print this number and the total size occupied by these files.

total_files=0
total_size=0

for file in "${files_array[@]}"; do
  if [ -f "$file" ]; then
    ((total_files++))

    file_size=$(du -k "$file" | cut -f1)
    ((total_size += file_size))
  fi
done

echo "$total_files files of size $total_size KB"

###########################################################################################################################
# REQ #3: Count the number of directories and print this number, also the names of directories with execution permissions.

total_dirs=0
executable_dirs=""

for dir in "${directories_array[@]}"; do
    if [ -d "$dir" ]; then
        ((total_dirs++))

        if [ -x "$dir" ]; then
            if [ -n "$executable_dirs" ]; then
                executable_dirs+=", "
            fi
            executable_dirs+="$dir"
        fi
    fi
done

echo "$total_dirs directories, of which $executable_dirs have execution permissions"

###########################################################################################################################
# REQ #4: Each valid number is added in the file mynumbers.txt on a separate line. The file must be sorted numerically decreasingly.

truncate -s 0 mynumbers.txt 2>/dev/null

number_regex='^[0-9]+$'

for num in "${numbers_array[@]}"; do
    if [[ $num =~ $number_regex ]]; then
        echo "$num" >> mynumbers.txt
    fi
done

sort -nr -o mynumbers.txt mynumbers.txt
