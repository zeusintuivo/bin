#!/usr/bin/env python3
# Taken from http://askubuntu.com/questions/547437/find-delete-duplicated-files-on-multiple-harddisks-at-once

import os
import sys

total_filelist = []
total_names = []

def find_files(directory):
    l = []; l2 = []
    for root, dirs, files in os.walk(directory):
        for file in files:
            l.append(file)
            l2.append(root+"/"+file)
    return (l, l2)

i = 1
while i <= 10:
    try:
        dr = (sys.argv[i])
        print("Creating file list...", dr)
        total_filelist = total_filelist+find_files(dr)[1]
        total_names = total_names+find_files(dr)[0]
        i = i+1
    except IndexError:
        break

print("Checking for duplicates ("+str(len(total_names)),"files)...")

for name in set(total_names):
    n = total_names.count(name)
    if n > 1:
        print("-"*60,"\n>  found duplicate:",
              name, n, "\n")
        for item in total_filelist:
            if item.endswith("/"+name):
                print(item)

print("-"*60, "\n")