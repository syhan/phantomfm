#!/bin/bash
cd "$(dirname "$0")"

mkdir -p .cache

echo $$ > .pid
echo $PPID > .ppid

source cred.sh

NETEASE_MUSIC_API=https://163.syhannnn.cf
PLAYLISTS=

if [ ! -f cookie.txt ]; then
  curl -s -c cookie.txt "${NETEASE_MUSIC_API}/login?email=${NETEASE_MUSIC_USERNAME}&password=${NETEASE_MUSIC_PASSWORD}" > .login.json

  if [ `jq -r '.code' .login.json` -ne 200 ]; then
    echo "login failed"
    exit 1
  fi
fi

log() {
  logger $1
  echo $1
}

play() {
  if [[ -f .cache/$1.mp3 ]]; then
    log "found $1 in cache"

    albumid=`jq -r '.songs[0].al.id' .cache/$1.detail.json`
    name=`jq -r '.songs[0].name' .cache/$1.detail.json`
  else
    log "check whether $1 is available"
    curl -s "${NETEASE_MUSIC_API}/check/music?id=$1" > .cache/$1.check.json

    jq -r '.message' .cache/$1.check.json
    if [[ `jq -r '.success' .cache/$1.check.json` -ne 'true' ]]; then
      rm .cache/$1.check.json
      return -1
    fi

    curl -s "${NETEASE_MUSIC_API}/song/detail?ids=$1" > .cache/$1.detail.json

    albumid=`jq -r '.songs[0].al.id' .cache/$1.detail.json`
    name=`jq -r '.songs[0].name' .cache/$1.detail.json`
    bitrate=`jq -r '.songs[0].l.br' .cache/$1.detail.json`

    curl -s -b cookie.txt "${NETEASE_MUSIC_API}/song/url?id=$1&br=$bitrate" > .cache/$1.url.json 

    url=`jq -r '.data[0].url' .cache/$1.url.json`
    if [[ "$url" == 'null' ]]; then
      log "cannot extract url for $name"
      rm .cache/$1.url.json .cache/$1.detail.json
      return -1
    fi

    log "downloading $name"
    curl -s $url -o .cache/$1.mp3
  fi

  log "playing $name"
  mpc add .cache/$1.mp3

  #log "scrobbling $name"
  #curl -s -b cookie.txt "${NETEASE_MUSIC_API}/scrobble?id=$1&sourceid=$albumid"

  return 0
}

NETEASE_ID=`jq -r '.account.id' .login.json`

favorite() {
  curl -s -b cookie.txt "${NETEASE_MUSIC_API}/likelist?uid=${NETEASE_ID}" | jq -r '.ids' | awk 'NR>2 {print last} {last=$0}' | sed -r 's/,$//g' | sed -r 's/^ +//g' | shuf | while read id; do
    play $id
  done
}

album() {
  mpc clear
  
  if [[ ! -f .cache/$1.album.json ]]; then
    curl -s "${NETEASE_MUSIC_API}/album?id=$1" > .cache/$1.album.json
  fi

  jq -r '.songs | sort_by(.no)[] | .id' .cache/$1.album.json | while read id; do
    play $id
  done

}

if [[ `jq -r "has(\"$1\")" meta.json` -ne 'true' ]]; then
  log "Cannot find metadata for this NFC tag $1， register it temporarily"
  jq ".\"$1\" = { type }" meta.json
  exit -1
fi

TYPE=`jq -r ".\"$1\"".type meta.json`
if [[ $TYPE -eq 'album' ]]; then
  album `jq -r ".\"$1\"".id meta.json`
elif [[ $TYPE -eq 'favorite' ]]; then
  favorite
fi


