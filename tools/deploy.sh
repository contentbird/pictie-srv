#!/bin/bash
# Deploy script to heroku
currentBranch() {
  git branch | grep "*" | sed "s/* //"
}

safeMatchingEnvForBranch() {
  case $1 in
    "dev") env="pictie";;
    "master") env="pictie";;
    *) echo "no matching env for $1"
       exit ;;
  esac
  echo "$env"
}

case $1 in
  # "pictie-dev") branch="dev"
  #               heroku_app="$1";;
  "pictie")     branch="master"
                heroku_app="$1";;
  "") branch=$(currentBranch)
      heroku_app=$(safeMatchingEnvForBranch $(currentBranch))
      echo "No target env specified: safely deploying to $heroku_app";;
  *) echo "Choose between 'pictie' or 'pictie-dev' !"
     exit ;;
esac

echo "-- Pushing $branch to $heroku_app"
git checkout $branch

if [ "$?" = "0" ]; then
  echo "-- Pushing to GitHub"
  git push github $branch

  if [ "$?" = "0" ]; then
    echo "-- Pushing to Heroku"
    git push $heroku_app $branch:master
  fi
fi