# Pictie Server

## Description
A messaging server in node.js using [FAYE](https://github.com/jcoglan/faye)

## Installation
* Get the code : `git clone https://github.com/railsagile/quintonic-chat.git`
* Install Node.js & Npm: Mac OS X users get .pkg from [here](http://nodejs.org/dist/latest/), Linux users use this [link](http://gist.github.com/579814)
* Download & install node dependencies : `npm install`
* Install foreman : `gem install foreman`

## Run example on local server
* Run the server in one terminal
``` shell
foreman start
```

## Dev & test
* Run coffeescript
``` shell
coffee -c -w -o lib/ src/
```

* Run tests with mocha
``` shell
./node_modules/mocha/bin/mocha -w -R spec --compilers coffee:coffee-script spec/*
```

## Deploy
* Add required remotes
``` shell
git remote add github git@github.com:contentbird/pictie-srv.git
```

* Run deploy script
``` shell
sh ./tools/deploy.sh pictie
```
You can add the following lines to your .bashrc (Linux) or .bash_profile (Max OSX):
``` shell
alias deploy='./tools/deploy.sh'
chmod +x ./tools/deploy.sh
```
and now you can deploy to the server matching your current branch in one word :)
``` shell
deploy
```