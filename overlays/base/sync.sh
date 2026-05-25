#!/bin/bash

# https://github.com/rime/squirrel/issues/421
if [ -n "$(pgrep 'Squirrel')" ]; then 
  cpu_usage=$(ps -p $(pgrep 'Squirrel') -o %cpu=);
  if [ "$(echo "$cpu_usage == 0" | bc -l)" -eq 1 ]; then 
    cd ~/Library/Rime && DYLD_LIBRARY_PATH="/Library/Input Methods/Squirrel.app/Contents/Frameworks" "/Library/Input Methods/Squirrel.app/Contents/MacOS/Squirrel" --quit && DYLD_LIBRARY_PATH="/Library/Input Methods/Squirrel.app/Contents/Frameworks" "/Library/Input Methods/Squirrel.app/Contents/MacOS/rime_dict_manager" -s; 
    fi;
fi


# https://github.com/rime/squirrel/issues/49
# 自动换输入法
