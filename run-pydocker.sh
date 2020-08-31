#!/usr/bin/env bash

set -ex

pwd="$PWD"

declare -a ARGS

img=runsascoded/py3.8
name="$(basename "$pwd")"
port=8899
apts=
pips=

while [ $# -gt 0 ]
do
    unset OPTIND
    unset OPTARG
    while getopts ":a:i:n:p:P: :b:ij:r:s:" opt
    do
      case "$opt" in
        a) IFS=, read -ra apts <<< "$OPTARG";;
        i) img="$OPTARG";;
        n) name="$OPTARG";;
        p) IFS=, read -ra pips <<< "$OPTARG";;
        P) port="$OPTARG";;
        *) ;;
      esac
    done
    shift $((OPTIND-1))
    ARGS+=("$1")
    if [ $# -gt 0 ]; then
      shift
    fi
done

dst="/$name"

dir="$(mktemp -d)"
clean() {
  if [ -s "$dir" ]; then
    echo "Cleanup dir: $dir"
    rm -rf "$dir"
  fi
}
trap clean EXIT
pushd "$dir"

docker=
dockerfile="$pwd/Dockerfile"
if [ -e "$dockerfile" ]; then
  docker=1
  cp "$dockerfile" Dockerfile
else
  echo "FROM $img" >> Dockerfile
fi
if [ ${#apts[@]} -gt 0 ]; then
  docker=1
  echo "RUN apt-get update && apt-get install ${apts[*]}" >> Dockerfile
fi
if [ ${#apts[@]} -gt 0 ]; then
  docker=1
  echo "RUN pip install ${pips[*]}" >> Dockerfile
fi
if [ -n "$docker" ]; then
  img="$name"
  docker build -t "$img" .
fi

uid="$(id -u)"
gid="$(id -g)"

if docker container inspect "$name" &>/dev/null; then
  docker container rm "$name"
fi
docker run \
       -v "$pwd:$dst" \
       --workdir "$dst" \
       -p "$port:$port" \
       -u "$uid:$gid" \
       --name "$name" \
       -e "HOME=/home" \
       -it \
       "$name" \
       "$port"

popd
