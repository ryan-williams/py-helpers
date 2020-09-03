#!/usr/bin/env bash

set -e

pwd="$PWD"

declare -a ARGS

img=runsascoded/py3.8
name="$(basename "$pwd")"
port=8899
apts=()
pips=()
skip_req_txt=
shell=

while [ $# -gt 0 ]
do
    unset OPTIND
    unset OPTARG
    while getopts ":a:i:n:p:P:Rs" opt
    do
      case "$opt" in
        a) IFS=, read -ra apts <<< "$OPTARG";;
        i) img="$OPTARG";;
        n) name="$OPTARG";;
        p) IFS=, read -ra pips <<< "$OPTARG";;
        P) port="$OPTARG";;
        R) skip_req_txt=1;;
        s) shell=1;;
        *) ;;
      esac
    done
    shift $((OPTIND-1))
    if [ $# -gt 0 ]; then
      ARGS+=("$1")
      shift
    fi
done

dst="/$name"

dir="$(mktemp -d)"
clean() {
  if test -s "$dir" && test -e "$dir"; then
    echo "Cleanup dir $dir"
    rm -rf "$dir"
  fi
}
trap clean EXIT

docker=
dockerfile="$pwd/Dockerfile"
tmp_dockerfile="$dir/Dockerfile"
if [ -e "$dockerfile" ]; then
  docker=1
  cp "$dockerfile" "$tmp_dockerfile"
else
  echo "FROM $img" >> "$tmp_dockerfile"
fi
if [ ${#apts[@]} -gt 0 ]; then
  docker=1
  echo "RUN apt-get update && apt-get install" "${apts[@]}" >> "$tmp_dockerfile"
fi
reqs_txt="$pwd/requirements.txt"
if [ -e "$reqs_txt" ] && [ -z "$skip_req_txt" ]; then
  IFS=$'\n' read -d '' -ra reqs < "$reqs_txt" || [ ${#reqs[@]} -gt 0 ]
  echo "Found ${#reqs[@]} reqs:" "${reqs[@]}"
  pips+=( "${reqs[@]}" )
fi
if [ ${#pips[@]} -gt 0 ]; then
  docker=1
  echo "RUN pip install" "${pips[@]}" >> "$tmp_dockerfile"
fi
if [ -n "$docker" ]; then
  img="$name"
  docker build -t "$img" -f "$tmp_dockerfile" "$dir"
fi

rm -rf "$dir"

uid="$(id -u)"
gid="$(id -g)"

if docker container inspect "$name" &>/dev/null; then
  docker container rm "$name"
fi

user_name="$(git config user.name)"
user_email="$(git config user.email)"

if [ -n "$shell" ]; then
  flags=( "--entrypoint" "/bin/bash" )
  args=()
else
  flags=()
  args=( "$port" )
fi

docker run \
       -v "$pwd:$dst" \
       --workdir "$dst" \
       -p "$port:$port" \
       -u "$uid:$gid" \
       --name "$name" \
       -e "HOME=/home" \
       -e "GIT_AUTHOR_NAME=$user_name" \
       -e "GIT_AUTHOR_EMAIL=$user_email" \
       -e "GIT_COMMITTER_NAME=$user_name" \
       -e "GIT_COMMITTER_EMAIL=$user_email" \
       -it \
       "${flags[@]}" \
       "$img" \
       "${args[@]}"
