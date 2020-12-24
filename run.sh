#!/bin/bash

PROGRAM_NAME="$(basename "${0}")"

logdate() {
    date "+%Y-%m-%d %H:%M:%S"
}

log() {
    local status="${1}"
    shift

    echo >&2 "$(logdate): ${PROGRAM_NAME}: ${status}: ${*}"

}

warning() {
    log WARNING "${@}"
}

error() {
    log ERROR "${@}"
}

info() {
    log INFO "${@}"
}

fatal() {
    log FATAL "${@}"
    exit 1
}

do_job() {
    local -n params=$1
    repo=${params[0]}
    branch=${params[1]}
    entrypoint=${params[2]}
    ospackage=${params[3]}

    rm -rf ~/repo/$repo
    git config --global http.https://github.com/.extraheader "Authorization: Basic $(echo -n "$GITHUB_ACTOR:$PAT" | base64 --wrap=0)"
    git clone -b $branch --depth 1 https://github.com/$GITHUB_ACTOR/$repo ~/repo/$repo
    cd ~/repo/$repo
    git submodule sync --recursive
    git -c protocol.version=2 submodule update --init --force --depth=1 --recursive
    git config --global --unset-all 'http.https://github.com/.extraheader'

    if [ -n "$ospackage" ]; then
        readarray -td, packages <<<"$ospackage"
        declare -p packages
        sudo apt-get install -y ${packages[@]}
    fi

    python -m pip install -r requirements.txt
    python $entrypoint
    git add .
    git commit -m "Job: $(date +%d.%m.%Y)" || echo "Nothing to update"
    git push "https://${GITHUB_ACTOR}:${PAT}@github.com/${GITHUB_ACTOR}/${repo}.git" HEAD:${branch}
}

# sudo apt-get update
mkdir ~/repo

git config --global user.email "python-jobs-action@users.noreply.github.com"
git config --global user.name "python-jobs Github Action Bot"

i=1
while IFS= read -r repo_entrypoint_ospackage; do
    info "Got job ${i}"
    cd ~

    vars=($repo_entrypoint_ospackage)
    &>/dev/null do_job vars

    cd ~/
    info "Job ${i} done"
    i=$((i + 1))
done <<<"$REPO"
