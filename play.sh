#! /bin/bash

source cred.sh

NETEASE_MUSIC_API=https://syhan-netease-cloud-music-api.vercel.app
PLAYLISTS=

if [ ! -f cookie.txt ]; then
  curl -s -c cookie.txt "${NETEASE_MUSIC_API}/login?email=${NETEASE_MUSIC_USERNAME}&password=${NETEASE_MUSIC_PASSWORD}" > .login.json


  if [ `jq -r '.code' .login.json` -ne 200 ]; then
    echo "Login failed"
    exit 1
  fi
fi

play() {
  echo "check whether $1 is available"
  curl -s "${NETEASE_MUSIC_API}/check/music?id=$1" > .check.json

  jq -r '.message' .check.json
  if [[ `jq -r '.success' .check.json` -ne 'true' ]]; then
    rm .check.json
    return -1
  fi

  curl -s "${NETEASE_MUSIC_API}/song/detail?ids=$1" > .detail.json
  albumid=`jq -r '.songs[0].al.id' .detail.json`
  name=`jq -r '.songs[0].name' .detail.json`
  bitrate=`jq -r '.songs[0].l.br' .detail.json`

  curl -s -b cookie.txt "${NETEASE_MUSIC_API}/song/url?id=$1&br=$bitrate" > .url.json 

  url=`jq -r '.data[0].url' .url.json`
  if [[ "$url" == 'null' ]]; then
    echo "cannot extract url for $name"
    rm .url.json .detail.json
    return -1
  fi

  echo "downloading $name"
  curl -s $url -o /tmp/$1.mp3

  echo "playing $name"
  mpg321 -x /tmp/$1.mp3

  echo "scrobbling $name"
  curl -s -b cookie.txt "${NETEASE_MUSIC_API}/scrobble?id=$1&sourceid=$albumid"

  rm -f .check.json .url.json .detail.json /tmp/$1.mp3
  return 0
}

NETEASE_ID=`jq -r '.account.id' .login.json`

curl -s -b cookie.txt "${NETEASE_MUSIC_API}/likelist?uid=${NETEASE_ID}" | jq -r '.ids' | awk 'NR>2 {print last} {last=$0}' | sed -r 's/,$//g' | sed -r 's/^ +//g' | shuf | while read id; do
  play $id
done
