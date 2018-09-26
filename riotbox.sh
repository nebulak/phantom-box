# Base system: debian stretch
SCRIPT_NAME="$0"
ARGS="$@"
UPDATE_URL="https://nebulak.github.io/riot-box"
VERSION="0.0.0"
COMMAND=$1

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

function render_template() {
  eval "echo \"$(cat $1)\""
}

function generate_prosody_conf {
  echo "#### Creating /tmp/httpd.conf from template ./httpd.conf.tmpl"
  render_template ./templates/prosody/prosody.cfg.lua.tmpl > /etc/prosody/prosody.cfg.lua
}


################ Functions ##############################



install() {
    ############################## PASSWORD SETUP ####################################
    # Get password for admin account
    echo_n "Enter the password you want to use for your yunohost admin account and the root user"
    read -s -p "Password: " PASSWORD; echo
    read -s -p "Confirm Password: " PASSCONFIRM; echo

    if [[ "$PASSWORD" != "$PASSCONFIRM" ]]; then
     echo "Passwords do not match, exiting..."
     echo "Restart this script and try again!"
     exit -1
    fi

    # //change root password
    echo root:$PASSWORD | chpasswd


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
    apt-get install apt-transport-https

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
    apt update && apt install prosody lua-dbi-mysql lua-sql-mysql lua-sec
    # //mod_onions dependencies
    # source: https://elbinario.net/2015/12/14/instalar-y-configurar-mod_onions-en-prosody/
    apt-get install liblua5.1-bitop0 liblua5.1-bitop-dev lua-bitop

    # delete default config
    cd /etc/prosody/
    > prosody.cfg.lua

    # create new config with template
    # source: https://dzone.com/articles/bash-script-to-generate-config-or-property-file-fr
    # //TODO: create random user and password and create user
    PROSODY_ADMIN_USER = ""
    PROSODY_ADMIN_PASSWORD = ""
    generate_prosody_conf()

    # install prosody modules
    apt-get install mercurial
    hg clone https://hg.prosody.im/prosody-modules/ prosody-modules
    cp prosody-modules/mod_onions/mod_onions.lua /usr/lib/prosody/modules/
    prosodyctl restart


    ##################### Web-Storage ###############################

    wget https://raw.githubusercontent.com/phantom-box/phantom-storage/master/phantom-storage
    chmod +x ./phantom-storage
    ./phantom-storage install
    ./phantom-storage init
    # //TODO: pass password to storage init
}

update() {
  install()
}

backup() {
  # //TODO:
}

restore() {
  # //TODO:
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
        *)
            echo $"Usage: $0 {install|update|uninstall}"
            exit 1

esac
