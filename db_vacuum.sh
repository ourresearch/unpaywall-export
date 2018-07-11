#!/bin/bash

echo "vac pub_queue";
. $HOME/.bash_profile;
. $HOME/.bashrc;

# workaround for needed path below
PATH=$PATH:/usr/local/bin:.
export PATH

# from https://toolbelt.heroku.com/install.sh

###########

set -e
SUDO=''
if [ "$(id -u)" != "0" ]; then
  SUDO='sudo'
  echo "This script requires superuser access."
  echo "You will be prompted for your password by sudo."
  # clear any previous sudo permission
  sudo -k
fi


# run inside sudo
$SUDO bash <<SCRIPT
set -ex

echoerr() { echo "\$@" 1>&2; }

if [[ ! ":\$PATH:" == *":/usr/local/bin:"* ]]; then
echoerr "Your path is missing /usr/local/bin, you need to add this to use this installer."
exit 1
fi

if [ "\$(uname)" == "Darwin" ]; then
OS=darwin
elif [ "\$(expr substr \$(uname -s) 1 5)" == "Linux" ]; then
OS=linux
else
echoerr "This installer is only supported on Linux and MacOS"
exit 1
fi

ARCH="\$(uname -m)"
if [ "\$ARCH" == "x86_64" ]; then
ARCH=x64
elif [[ "\$ARCH" == arm* ]]; then
ARCH=arm
else
echoerr "unsupported arch: \$ARCH"
exit 1
fi

mkdir -p /usr/local/lib
cd /usr/local/lib
rm -rf heroku
rm -rf ~/.local/share/heroku/client
curl https://cli-assets.heroku.com/heroku-\$OS-\$ARCH.tar.xz | tar xJ
rm -f /usr/local/bin/heroku
ln -s /usr/local/lib/heroku/bin/heroku /usr/local/bin/heroku

if [ -f /usr/local/heroku/bin/heroku ]; then
ln -fs /usr/local/bin/heroku /usr/local/heroku/bin/heroku
fi

# test the CLI
LOCATION=$(which heroku)
echo "heroku installed to $LOCATION"
heroku version

#############

heroku ps:scale update=0 --app=oadoi

heroku pg:killall --app=oadoi

psql $DATABASE_URL -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE state = 'idle in transaction'";
psql $DATABASE_URL -c "vacuum full verbose analyze pub_queue"

heroku ps:scale update=30 --app=oadoi
