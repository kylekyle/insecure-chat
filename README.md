# Insecure Chat

The West Point instance is hosted at https://insecure.compute.army/.

Insecure Chat is a chat room for teaching students about cross-site scripting (XSS) and session hi-jacking. 

If you are looking for a secure chat room implementation, check out [LockDown Chat](https://github.com/kylekyle/lockdown-chat).

## Deploying

Insecure Chat is written in Ruby 2.7 and built atop the [Roda routing tree web toolkit](https://github.com/jeremyevans/roda). The service script assumes that ruby was installed using [RVM](https://rvm.io/) and the gemset is aliased as follows: 

```bash
$ rvm install 2.7.1
$ rvm alias create insecure-chat ruby-2.7.1@insecure-chat --create
$ rvm use insecure-chat
```

To install project dependencies, run: 

```bash
$ git clone https://github.com/kylekyle/lockdown-chat
$ cd lockdown-chat
$ bundle install
```

Next, create a `.env` file in the project directory that defines the following variables: 

```bash
# the secret and key to authenticates LTI requests from canvas
LTI_KEY=
LTI_SECRET=

# this is used to encrypt session cookies
SESSION_SECRET=
```

While you can pass certificate inormation directly to the [Puma](https://github.com/puma/puma) backend, I recommend using a reverse proxy like [nginx](https://www.nginx.com/). See the config directory for an [example nginx config](config/nginx.conf).

To get a free certificate from [Let's Encrypt!](https://letsencrypt.org), do the following:

```bash 
$ apt install certbot
$ certbot -d INSECURE_CHAT_SERVER_DOMAIN --nginx
```

You can automatically renew the certificate by running `crontab -e` and adding the following line:

```
12 3 * * * certbot renew --post-hook "service nginx restart" -q
```

To configure the insecure chat server to start automatically when you boot:

```bash
~ $ sudo cp config/insecure-chat.service /etc/systemd/system/
~ $ sudo systemctl enable insecure-chat.service 
~ $ sudo service insecure-chat start
```

## Configuring Canvas

To add Insecure Chat to your course, go to *Settings* -> *Apps* in Canvas and add a new app. Enter the LTI key and secret from your `.env`, select `Paste XML`, and paste in the XML from here: 

> https://<INSECURE_CHAT_SERVER_DOMAIN>/config.xml

## Building the webpack bundle

If you need to make changes to `chat.js`, you'll need to re-build the bundle. The bundle was originally built using Node 14.6.0. To re-build: 

```bash
$ cd webpack
$ npm install
$ npx webpack 
```

The bundle and dependencies are output to the `public/dist` directory in the project root. 