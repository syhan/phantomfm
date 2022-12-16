#!/bin/bash
cd "$(dirname "$0")"

kill -9 `cat .ppid`
kill -9 `cat .pid`
mpc stop
mpc clear
rm -f .*.json .pid .ppid

