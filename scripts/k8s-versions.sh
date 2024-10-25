#!/bin/bash

API_URL="https://hub.docker.com/v2/repositories/kindest/node/tags"

fetch_tags() {
    local page=$1
    curl -s "${API_URL}?page=${page}&page_size=100" | jq -r '
        if .results then
            .results[] | select(.name != null and .images != null and (.images | length > 0) and
            (.images | map(.architecture) | unique | length > 1)) |
            "\(.name) \(.digest)"
        else
            empty
        end
    '
}

list_tags() {
    local page=1
    local all_tags=""

    while true; do
        tags=$(fetch_tags $page)

        if [ -z "$tags" ]; then
            break
        fi

        all_tags+="$tags"$'\n'
        ((page++))
    done

    echo "$all_tags" | sort -V
}

get_sha256() {
    local version=$1
    list_tags | grep "^$version " | cut -d' ' -f2
}

case "$1" in
    list)
        list_tags
        ;;
    *)
        if [[ $1 =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            get_sha256 "$1"
        else
            echo "Usage: $0 list"
            echo "       $0 <semantic_version>"
            exit 1
        fi
        ;;
esac
