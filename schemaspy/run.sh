#!/bin/bash
rm -fr html
mkdir html
java -jar schemaspy-6.1.0.jar \
     -configFile ./config.txt \
     -hq -imageformat svg \
     -norows -rails -renderer :cairo -vizjs -degree 2

