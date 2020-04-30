#!/bin/sh
set -e

function main() {
  echo "" # see https://github.com/actions/toolkit/issues/168

  sanitize "${INPUT_NAME}" "name"

  translateDockerTag

  if uses "${INPUT_WORKDIR}"; then
    changeWorkingDirectory
  fi

  FIRST_TAG=$(echo $TAGS | cut -d ' ' -f1)
  DOCKERNAME="${INPUT_NAME}:ci"
  BUILDPARAMS=""
  CONTEXT="."

  if uses "${INPUT_DOCKERFILE}"; then
    useCustomDockerfile
  fi

  build

  echo ${INPUT_TESTCOMMAND}

  if uses "${INPUT_TESTCOMMAND}"; then
    TESTOUTPUT=`eval ${INPUT_TESTCOMMAND}`
    echo $TESTOUTPUT
  fi
}

function sanitize() {
  if [ -z "${1}" ]; then
    >&2 echo "Unable to find the ${2}. Did you set with.${2}?"
    exit 1
  fi
}

function isPartOfTheName() {
  [ $(echo "${INPUT_NAME}" | sed -e "s/${1}//g") != "${INPUT_NAME}" ]
}

function translateDockerTag() {
  local BRANCH=$(echo ${GITHUB_REF} | sed -e "s/refs\/heads\///g" | sed -e "s/\//-/g")
  if hasCustomTag; then
    TAGS=$(echo ${INPUT_NAME} | cut -d':' -f2)
    INPUT_NAME=$(echo ${INPUT_NAME} | cut -d':' -f1)
  elif isOnMaster; then
    TAGS="latest"
  elif isGitTag && usesBoolean "${INPUT_TAG_SEMVER}" && isSemver "${GITHUB_REF}"; then
    TAGS=$(echo ${GITHUB_REF} | sed -e "s/refs\/tags\///g" | sed -E "s/v?([0-9]+)\.([0-9+])\.([0-9]+)(-[a-zA-Z]+(\.[0-9]+)?)?/\1.\2.\3\4 \1.\2\4 \1\4/g")
  elif isGitTag && usesBoolean "${INPUT_TAG_NAMES}"; then
    TAGS=$(echo ${GITHUB_REF} | sed -e "s/refs\/tags\///g")
  elif isGitTag; then
    TAGS="latest"
  elif isPullRequest; then
    TAGS="${GITHUB_SHA}"
  else
    TAGS="${BRANCH}"
  fi;
}

function hasCustomTag() {
  [ $(echo "${INPUT_NAME}" | sed -e "s/://g") != "${INPUT_NAME}" ]
}

function isOnMaster() {
  [ "${BRANCH}" = "master" ]
}

function isGitTag() {
  [ $(echo "${GITHUB_REF}" | sed -e "s/refs\/tags\///g") != "${GITHUB_REF}" ]
}

function isPullRequest() {
  [ $(echo "${GITHUB_REF}" | sed -e "s/refs\/pull\///g") != "${GITHUB_REF}" ]
}

function changeWorkingDirectory() {
  cd "${INPUT_WORKDIR}"
}

function useCustomDockerfile() {
  BUILDPARAMS="${BUILDPARAMS} -f ${INPUT_DOCKERFILE}"
}

function uses() {
  [ ! -z "${1}" ]
}

function usesBoolean() {
  [ ! -z "${1}" ] && [ "${1}" = "true" ]
}

function isSemver() {
  echo "${1}" | grep -Eq '^refs/tags/v?([0-9]+)\.([0-9+])\.([0-9]+)(-[a-zA-Z]+(\.[0-9]+)?)?$'
}

function build() {
  local BUILD_TAGS="-t ${DOCKERNAME}"
  echo "docker build ${INPUT_BUILDOPTIONS} ${BUILDPARAMS} ${BUILD_TAGS} ${CONTEXT}"
  docker build ${INPUT_BUILDOPTIONS} ${BUILDPARAMS} ${BUILD_TAGS} ${CONTEXT}
}

main
