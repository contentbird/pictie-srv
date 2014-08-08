# Pictie Server

A messaging server in node.js using [FAYE](https://github.com/jcoglan/faye) and [Express](http://expressjs.com/)

### Contents
- [Installation](#install)
- [Configuration](#config)
- [Dev & Test](#devtest)

##<a name="install"></a> Installation
* Get the code : `git clone https://github.com/railsagile/quintonic-chat.git`
* Install Node.js & Npm: Mac OS X users get .pkg from [here](http://nodejs.org/dist/latest/), Linux users use this [link](http://gist.github.com/579814)
* Download & install node dependencies : `npm install`
* Install foreman : `gem install foreman`
* Run on local server
``` shell
foreman start
```

##<a name="config"></a> Configuration

### Configure APNS (Apple Push Notification Service)

In order to connect with Apple Servers, the server must have access to the certificates

* Retrieve __pictie_aps_<development|production>.p12__ and __pictie_aps_<development|production>.cer__ files from vault
* Follow instructions [here](https://github.com/argon/node-apn/wiki/Preparing-Certificates) to generate __apn_cert_<env>.pem__ and __apn_key_<env>.pem__
 - For __local__ server, put these 2 files in /certs directory
 - For __production__ server you must set two environment variables : APN_CERT_PEM & APN_KEY_PEM
   In order to set those 2 multiline variables do the following:
   ``` shell
   thevar=$(cat ./certs/apn_key.pem)
   heroku config:add APN_KEY_PEM="$thevar" -a pictie-dev
   ```
### Configure GCM (Google Cloud Messaging)

In order to connect with Google Servers, you need to:

* Set the GCM_API_KEY environment variable with your Google API Key


##<a name="devtest"></a> Dev & test
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