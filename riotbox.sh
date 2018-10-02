# Base system: debian stretch
SCRIPT_NAME="$0"
ARGS="$@"
UPDATE_URL="https://nebulak.github.io/riot-box"
VERSION="0.0.0"
COMMAND=$1

############################## DEPENDENCIES     ####################################
# tinylogger.bash - A simple logging framework for Bash scripts in < 10 lines
# https://github.com/nk412/tinylogger
# defaults
LOGGER_FMT="%Y-%m-%d %H:%M:%S"
LOGGER_LVL="info"
LOGGER_FILE="/riotbox_log.txt"

function tlog {
    action=$1 && shift
    case $action in 
        debug)  [[ $LOGGER_LVL =~ debug ]]           && echo "$( date "+${LOGGER_FMT}" ) - DEBUG - $@" >> LOGGER_FILE ;;
        info)   [[ $LOGGER_LVL =~ debug|info ]]      && echo "$( date "+${LOGGER_FMT}" ) - INFO - $@" >> LOGGER_FILE  ;;
        warn)   [[ $LOGGER_LVL =~ debug|info|warn ]] && echo "$( date "+${LOGGER_FMT}" ) - WARN - $@" >> LOGGER_FILE  ;;
        error)  [[ ! $LOGGER_LVL =~ none ]]          && echo "$( date "+${LOGGER_FMT}" ) - ERROR - $@" >> LOGGER_FILE ;;
    esac
true; }


############################## HELPER FUNCTIONS ####################################
# source: https://misc.flogisoft.com/bash/tip_colors_and_formatting
# source2: https://gist.github.com/daytonn/8677243
RED='\033[0;31m'
PURPLE="\033[0;35m"
GREEN="\033[0;32m"
NC='\033[0m'
# Print purple
function echo_n {
    echo -e "${PURPLE}${1}${NC}"
}

function echo_g {
    echo -e "${GREEN}${1}${NC}"
}

function render_template {
  eval "echo \"$(cat $1)\""
}

function generate_prosody_conf {
  echo "#### Creating /tmp/httpd.conf from template ./httpd.conf.tmpl"
  render_template ./templates/prosody/prosody.cfg.lua.tmpl > /etc/prosody/prosody.cfg.lua
}

# source: https://bencane.com/2014/09/02/understanding-exit-codes-and-how-to-use-them-in-bash-scripts/
# source: https://unix.stackexchange.com/questions/119243/bash-script-to-output-path-to-usb-flash-memory-stick
function encrypt {
  # argument 1: plaint_text
  # argument 2: output path
  FILE=/riotbox.openpgp 
  if [ -f $FILE ]; then
     gpg --import /riotbox.openpgp
  else
    tlog error "File $FILE does not exist."
    exit 1
  fi
  echo $1 | gpg -ear riotbox@localhost --trust-model always > $2
  
  if [ $? -eq 0 ]
  then
    tlog debug "Successfully encrypted file with gpg."
  else
    tlog error "Unable to encrypt."
    echo "Unable to encrypt."
    exit 1
  fi
}


################ Functions ##############################



install() {
    ############################## PASSWORD SETUP ####################################
    # info: https://diceware.readthedocs.io/en/stable/readme.html#usage
    ROOT_PASSWORD=${diceware --wordlist en_eff -n 8}
    # //change root password
    echo root:$ROOT_PASSWORD | chpasswd


    ############################## SYSTEM UPDATE ####################################
    # Update package list
    echo_n "updating package list"
    apt-get -y update

    # upgrade
    echo_n "upgrading packages"
    apt-get -y upgrade
    echo_n "dist-upgrade"
    apt-get -y dist-upgrade


    echo_n "Installing apt-transport-https"
    apt-get install -y apt-transport-https
    apt-get install -y wget
    apt-get install -y diceware

    ############################## HIDDEN SERVICE CONFIGURATION ####################################
    # Tor installation & hidden service creation
    echo_n "Installing tor..."
    sudo apt-get -y install tor
    sudo systemctl enable tor

    echo_n "Creating hidden service..."
    echo '# Hidden service for ssh' >> /etc/tor/torrc
    echo 'HiddenServiceDir  /var/lib/tor/phantom/' >> /etc/tor/torrc
    # ssh
    echo 'HiddenServicePort 22 127.0.0.1:22' >> /etc/tor/torrc
    # Email Ports
    echo 'HiddenServicePort 25 127.0.0.1:25' >> /etc/tor/torrc
    echo 'HiddenServicePort 465 127.0.0.1:465' >> /etc/tor/torrc
    echo 'HiddenServicePort 587 127.0.0.1:587' >> /etc/tor/torrc
    echo 'HiddenServicePort 993 127.0.0.1:993' >> /etc/tor/torrc
    # XMPP Ports
    echo 'HiddenServicePort 5222 127.0.0.1:5222' >> /etc/tor/torrc
    echo 'HiddenServicePort 5269 127.0.0.1:5269' >> /etc/tor/torrc
    # Webserver
    echo 'HiddenServicePort 80 127.0.0.1:80' >> /etc/tor/torrc
    echo 'HiddenServicePort 443 127.0.0.1:443' >> /etc/tor/torrc

    echo_n "Restarting tor..."
    service tor restart
    echo_n "waiting for tor to generate hidden services(60s)"
    sleep 60

    HIDDEN_SERVICE="$(cat /var/lib/tor/phantom/hostname)"

    # //TODO: firewall configuration with ufw

    ##################### PROSODY ###############################
    # source: https://thomas-leister.de/prosody-xmpp-server-ubuntu/

    # install prosody and dependencies
    wget https://prosody.im/files/prosody-debian-packages.key -O- | sudo apt-key add -
    echo deb http://packages.prosody.im/debian $(lsb_release -sc) main | sudo tee -a /etc/apt/sources.list.d/prosody.list
    sudo apt-get -y update
    sudo apt-get -y upgrade
    
    sudo apt-get -y install prosody lua-dbi-mysql lua-sql-mysql lua-sec
    # //mod_onions dependencies
    # source: https://elbinario.net/2015/12/14/instalar-y-configurar-mod_onions-en-prosody/
    apt-get install -y liblua5.1-bitop0 liblua5.1-bitop-dev lua-bitop

    # delete default config
    cd /etc/prosody/
    > prosody.cfg.lua

    # create new config with template
    # source: https://dzone.com/articles/bash-script-to-generate-config-or-property-file-fr
    PROSODY_ADMIN_USER = "riotboxadmin"
    PROSODY_ADMIN_PASSWORD = ${diceware --wordlist en_eff -n 8}
    generate_prosody_conf()

    # install prosody modules
    # source: https://mgw.dumatics.com/prosody-behind-apache-on-debian-stretch/
    sudo apt-get install -y mercurial
    cd /usr/lib/prosody/
    sudo hg clone https://hg.prosody.im/prosody-modules/ prosody-modules
    
    prosodyctl restart


    ##################### Web-Storage ###############################
    cd /home/pi
    sudo apt-get install -y syncthing
    wget https://github.com/filebrowser/filebrowser/releases/download/v1.8.0/linux-armv7-filebrowser.tar.gz
    mkdir /var/riotbox_sh/bin
    mkdir /var/riotbox_sh/bin/filebrowser
    tar -xzf linux-armv7-filebrowser.tar.gz
    mv -v ./linux-armv7-filebrowser/* /var/riotbox_sh/bin/filebrowser
    
    sudo apt-get install -y libssl-dev
    git clone https://github.com/canha/golang-tools-install-script
    chmod +x ./golang-tools-install-script/goinstall.sh
    ./golang-tools-install-script/goinstall.sh --arm
    go get -d github.com/rfjakob/gocryptfs
    cd $(go env GOPATH)/src/github.com/rfjakob/gocryptfs
    ./build.bash
    sudo cp ./../../../../bin/gocryptfs /usr/local/bin/gocryptfs
    
    # init storage
    STORAGE_ENC_PASSWORD=${diceware --wordlist en_eff -n 8}
    mkdir /var/riotbox_sh/data
    mkdir /var/riotbox_sh/data_encrypted
    gocryptfs -init -extpass="echo $STORAGE_ENC_PASSWORD" /var/riotbox_sh/data_encrypted
    
}

unlock_storage() {
  ./gocryptfs -extpass="echo $1" /var/riotbox_sh/data_encrypted /var/riotbox_sh/data
  ./filebrowser -p 8080 -s /var/riotbox_sh/data &>/dev/null &
  syncthing &>/dev/null &
}

lock_storage() {
  pkill syncthing
  pkill filebrowser
  fusermount -u /var/riotbox_sh/data
  echo "Successfully locked storage"
}

update() {
  # //TODO:
}

backup() {
  # //TODO:
}

restore() {
  # //TODO:
}

lock() {
  lock_storage()
}

unlock() {
  unlock_storage($1)
}

case "$1" in
        install)
            install # install all package
            ;;

        update)
            install # update core and packages
            ;;

        backup)
            backup # update core and packages
            ;;
        restore)
            restore # uninstall one or all packages
            ;;
        unlock)
            unlock # uninstall one or all packages
            ;;
        lock)
            lock # uninstall one or all packages
            ;;
        *)
            echo $"Usage: $0 {install|update|unlock|lock|backup|restore}"
            exit 1

esac
