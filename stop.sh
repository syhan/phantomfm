#!/bin/bash

kill -9 `cat .ppid`
kill -9 `cat .pid`
pkill mpg321
rm -f .*.json .*.mp3 .pid .ppid
