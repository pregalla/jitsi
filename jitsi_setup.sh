#!/bin/bash
#set -x

# TODO: separate jitsi-meet, videobridge, jigasi, jibri installations

PRODUCT_NAME=jitsi
SCRIPT_NAME="${PRODUCT_NAME}_setup.sh"
SCRIPT_VERSION=1.0

CURRENT_USER=$(whoami)
CURRENT_WORKING_DIR=$(pwd)
CONFIG_FILE="$CURRENT_WORKING_DIR/${PRODUCT_NAME}_config_file"

LOCKFILE="/tmp/${PRODUCT_NAME}_setup.lock"

DATE=$(date +%d-%b-%Y-%H-%M-%S)
LOGDIR="$HOME/$PRODUCT_NAME"
LOGFILE="$LOGDIR/${SCRIPT_NAME}_$DATE.log"

# Operating System Details
OS_DISTRO=$(lsb_release -is)
OS_RELEASE=$(lsb_release -rs)
OS_CODENAME=$(lsb_release -cs)

# Directories to be removed(of older install) during UNINSTALL
TO_REMOVE_DIRS="
                /etc/jitsi 
                /etc/nginx
                /etc/prosody 
                /etc/init.d/prosody 
                /etc/init.d/nginx 
                /usr/share/jitsi*
                /usr/share/nginx 
                /usr/share/jicofo 
                /usr/share/jigasi
                /var/lib/jigasi 
                /var/lib/prosody 
                /var/lib/nginx"

# Log to $LOGFILE besides showing on the Terminal
# For empty line, simply use logit
# NOTE: Simply use echo if you have more than 1 parameter to echo

logit()
{
    if [ "$2" = "nostdout" ]
    then
        echo "$1" >> "$LOGFILE"
    else
        echo "$1"|tee -a "$LOGFILE"
    fi
}

show_start_time()
{
    logit "Start Time: $(date)"
    logit
}

show_end_time()
{
    logit
    logit "End Time: $(date)"
    logit
    logit "Logs for this run are saved in \"$LOGFILE\""
    logit

    release_lock
}

remove_old_directories()
{
    logit
    logit "Removing directories..."
    logit
    
    for dir in $TO_REMOVE_DIRS 
    do
        sudo rm -rf "$dir" && logit "Removed $dir"
    done
}

post_install_tasks()
{
    logit
    logit "***** Few Post Install Tasks for you *****"
    logit
    logit "0. Check the status of services in the log file(or scroll up)...All installed services should show (running)..."
    logit "1. Check /etc/hosts file for any duplicates entries and remove them..."
    logit "2. If you want Google's Transcription (Speech-To-Text) and forgot to set credentials, copy google credentials(service account, with 'Cloud Speech-to-Text' API enabled) file to $ACTUAL_GOOGLE_CREDS_PATH and restart Jigasi..."
    logit "3. If you want Vosk's Transcription (Speech-To-Text), you may run it as a docker on localhost using \"docker run -d -p 2700:2700 alphacep/kaldi-en:latest\""
    logit "4. Check log file of this run for these strings: NOTE, WARNING, ERROR, RECOMMENDED"
    logit
}

# Compares versions of format a.b.c
# Returns 0 if firstArg < secondArg (making condition is static)
# Rerurns 1 if not less than or equal to
version_compare() {
    version1=$1 version2=$2 condition='<'

    local IFS=.
    v1_array=($version1)
    v2_array=($version2)
    v1=$((v1_array[0] * 100 + v1_array[1] * 10 + v1_array[2]))
    v2=$((v2_array[0] * 100 + v2_array[1] * 10 + v2_array[2]))

    diff=$((v2 - v1))

    [[ $condition = '='  ]] && ((diff == 0)) && return 0
    [[ $condition = '!=' ]] && ((diff != 0)) && return 0
    [[ $condition = '<'  ]] && ((diff >  0)) && return 0
    [[ $condition = '<=' ]] && ((diff >= 0)) && return 0
    [[ $condition = '>'  ]] && ((diff <  0)) && return 0
    [[ $condition = '>=' ]] && ((diff <= 0)) && return 0
    return 1
}

install_aliases()
{
    ALIASES_VERSION=1.0
    ALIASES_FILE="/etc/jitsi/aliases_$PRODUCT_NAME"

    logit; logit "Installing $PRODUCT_NAME aliases (version $ALIASES_VERSION) to $ALIASES_FILE"

    sudo sh -c "cat > $ALIASES_FILE << EOF
# $PRODUCT_NAME: aliases version: $ALIASES_VERSION
# All start with prefix 'gd' (Don't ask why)
# Except the change directory ones, which start with 'cd'

alias gdopenaliases='vi $ALIASES_FILE'
alias gdreloadaliases='. $ALIASES_FILE'

alias ll='ls -lrt'

# Change directory
alias cdjigasi='cd /etc/jitsi/jigasi'
alias cdjicofo='cd /etc/jitsi/jicofo'
alias cdprosody='cd /etc/prosody/conf.d'
alias cdvideobridge='cd /etc/jitsi/videobridge'
alias cdjitsimeet='cd /etc/jitsi/meet'
alias cdjibri='cd /etc/jitsi/jibri'
alias cdnginx='cd /etc/nginx/sites-enabled'

alias cdlogsjitsi='cd /var/log/jitsi'
alias cdlogsprosody='cd /var/log/prosody'
alias cdlogsnginx='cd /var/log/nginx'
alias cdlogsjibri='cd /var/log/jitsi/jibri'

alias cdtranscripts='cd $JIGASI_TRANSCRIPTS_DIR'
alias cdrecordings='cd $JIBRI_RECORDINGS_DIR'

alias gdstatus-jigasi='/etc/init.d/jigasi status'
alias gdstart-jigasi='/etc/init.d/jigasi start'
alias gdstop-jigasi='/etc/init.d/jigasi stop'
alias gdrestart-jigasi='/etc/init.d/jigasi restart'

alias gdstatus-jibri='systemctl status jibri'
alias gdstart-jibri='systemctl start jibri'
alias gdstop-jibri='systemctl stop jibri'
alias gdrestart-jibri='systemctl restart jibri'

alias gdstatus-nginx='/etc/init.d/nginx status'
alias gdstart-nginx='/etc/init.d/nginx start'
alias gdstop-nginx='/etc/init.d/nginx stop'
alias gdrestart-nginx='/etc/init.d/nginx restart'

alias gdstatus-jicofo='/etc/init.d/jicofo status'
alias gdstart-jicofo='/etc/init.d/jicofo start'
alias gdstop-jicofo='/etc/init.d/jicofo stop'
alias gdrestart-jicofo='/etc/init.d/jicofo restart'

alias gdstatus-prosody='/etc/init.d/prosody status'
alias gdstart-prosody='/etc/init.d/prosody start'
alias gdstop-prosody='/etc/init.d/prosody stop'
alias gdrestart-prosody='/etc/init.d/prosody restart'

alias gdstatus-videobridge='/etc/init.d/jitsi-videobridge2 status'
alias gdstart-videobridge='/etc/init.d/jitsi-videobridge2 start'
alias gdstop-videobridge='/etc/init.d/jitsi-videobridge2 stop'
alias gdrestart-videobridge='/etc/init.d/jitsi-videobridge2 restart'

alias gdstart-all='gdstart-nginx; sleep 2; gdstart-prosody; sleep 2; gdstart-jigasi; sleep 2; gdstart-videobridge; sleep 2; gdstart-jibri; sleep 2; gdstart-jicofo'

alias gdstop-all='gdstop-videobridge; gdstop-jicofo; gdstop-jigasi; gdstop-jibri; gdstop-prosody; gdstop-nginx'

alias gdstatus-all='echo -n "nginx:"; gdstatus-nginx|grep Active; echo -n "videobridge:"; gdstatus-videobridge|grep Active; echo -n "jicofo:"; gdstatus-jicofo|grep Active; echo -n "prosody:"; gdstatus-prosody|grep Active; echo -n "jigasi:"; gdstatus-jigasi|grep Active; echo -n "jibri:"; gdstatus-jibri|grep Active'

alias gdrestart-all='echo; echo ***STOPPING***; gdstop-all; echo; echo ***STARTING***; sleep 2;gdstart-all; echo; echo ***STATUS***; sleep 2; gdstatus-all'

# open log files
alias gdopenlog-jigasi='vi /var/log/jitsi/jigasi.log'
alias gdopenlog-jicofo='vi /var/log/jitsi/jicofo.log'
alias gdopenlog-videobridge='vi /var/log/jitsi/jvb.log'
alias gdopenlog-prosody='vi /var/log/prosody/prosody.log'
alias gdopenlog-prosody-err='vi /var/log/prosody/prosody.err'
alias gdopenlog-nginx='vi /var/log/nginx/access.log'
alias gdopenlog-nginx-err='vi /var/log/nginx/error.log'
alias gdopenlog-jibri='vi /var/log/jitsi/jibri/log.0.txt'

# tail log files
alias gdtaillog-jigasi='tail -f /var/log/jitsi/jigasi.log'
alias gdtaillog-jicofo='tail -f /var/log/jitsi/jicofo.log'
alias gdtaillog-videobridge='tail -f /var/log/jitsi/jvb.log'
alias gdtaillog-prosody='tail -f /var/log/prosody/prosody.log'
alias gdtaillog-prosody-err='tail -f /var/log/prosody/prosody.err'
alias gdtaillog-nginx='tail -f /var/log/nginx/access.log'
alias gdtaillog-nginx-err='tail -f /var/log/nginx/error.log'
alias gdtaillog-jibri='tail -f /var/log/jitsi/jibri/log.0.txt'
EOF
"
    logit "Installing $PRODUCT_NAME aliases (version $ALIASES_VERSION) to $ALIASES_FILE: COMPLETE..."

    logit
    logit "You may load them to your current session using: source $ALIASES_FILE"
    logit
}

show_service_status()
{
    logit
    logit "****** Current status of services *****"
    
    echo -n "nginx:"|tee -a "$LOGFILE"; systemctl status nginx|grep Active|tee -a "$LOGFILE"
    echo -n "prosody:"|tee -a "$LOGFILE"; systemctl status prosody|grep Active|tee -a "$LOGFILE"
    echo -n "jitsi-videobridge2:"|tee -a "$LOGFILE"; systemctl status jitsi-videobridge2|grep Active|tee -a "$LOGFILE"
    echo -n "jicofo:"|tee -a "$LOGFILE"; systemctl status jicofo|grep Active|tee -a "$LOGFILE"

    echo -n "jigasi:"|tee -a "$LOGFILE"
    if is_jigasi_installed
    then
        systemctl status jigasi|grep Active|tee -a "$LOGFILE"
    else
        logit " *** jigasi is not installed... ***"
    fi

    echo -n "jibri:"|tee -a "$LOGFILE";
    if is_jibri_installed
    then
        systemctl status jicofo|grep Active|tee -a "$LOGFILE"
    else
        logit " *** jibri is not installed... ***"
    fi
}

stop_services()
{   
    logit
    logit "STOPPING services..."
  
    sudo systemctl stop jitsi-videobridge2
    sudo systemctl stop jicofo
    
    is_jigasi_installed && sudo systemctl stop jigasi
    
    sudo systemctl stop prosody
    
    is_jibri_installed && sudo systemctl stop jibri
    
    sudo systemctl stop nginx
    
    #Wait for few seconds so that services are all stopped
    sleep 5

    logit "STOPPING services: COMPLETE..."
    logit
}

start_services()
{
    logit
    logit "STARTING services..." 
    
    sudo systemctl start nginx
    sudo systemctl start prosody
    
    is_jigasi_installed && sudo systemctl start jigasi
    
    sudo systemctl start jitsi-videobridge2
    
    is_jibri_installed && sudo systemctl start jibri
    
    sudo systemctl start jicofo
    
    #Wait for few seconds so that services are all started
    sleep 5
    
    logit "STARTING services: COMPLETE..."
    logit
}
 
restart_services()
{
    logit
    logit "Restarting services..."
    stop_services 
    sleep 5
    start_services
    logit "Restarting services: COMPLETE..."
    logit
}

show_installed_versions()
{
    logit
    logit "$(date): Currently Installed Versions:"
    logit "************************************************************"
    dpkg -l|grep "nginx-full"|tee -a "$LOGFILE"
    dpkg -l|grep "jitsi"|tee -a "$LOGFILE"
    dpkg -l|grep "prosody"|tee -a "$LOGFILE"
    dpkg -l|grep "jigasi"|tee -a "$LOGFILE"
    dpkg -l|grep "jibri"|tee -a "$LOGFILE"
    logit "************************************************************"
    logit
}

kill_lingering_processes()
{
    logit "Checking if any services are still alive...If so kill them..."
    #To be safe, kill any unstopped ones
    sudo pgrep -f jitsi-videobridge2 > /dev/null && sudo pkill -f jitsi-videobridge2
    sudo pgrep -f jicofo > /dev/null && sudo pkill -f jicofo
    sudo pgrep -f jigasi > /dev/null && sudo pkill -f jigasi
    sudo pgrep -f prosody > /dev/null && sudo pkill -f prosody
    sudo pgrep -f nginx > /dev/null && sudo pkill -f nginx
}

configure_firewall()
{
    sudo ufw allow 80/tcp
    sudo ufw allow 443/tcp
    sudo ufw allow 10000/udp
    sudo ufw allow 22/tcp
    sudo ufw allow 3478/udp
    sudo ufw allow 5349/tcp
    sudo ufw allow 5222/tcp

    #start the firewall
    echo y|sudo ufw enable
}

modify_systemd_limits()
{
   
    if [[ ! $(systemctl show --property DefaultLimitNOFILE) =~ .*65000$ ]]
    then
        logit "DefaultLimitNOFILE=65000"|sudo tee -a /etc/systemd/system.conf > /dev/null
    fi

    if [[ ! $(systemctl show --property DefaultLimitNPROC) =~ .*65000$ ]]
    then
        echo "DefaultLimitNPROC=65000"|sudo tee -a /etc/systemd/system.conf > /dev/null
    fi
    
    if [[ ! $(systemctl show --property DefaultTasksMax) =~ .*65000$ ]]
    then
        echo "DefaultTasksMax=65000"|sudo tee -a /etc/systemd/system.conf > /dev/null
    fi

    sudo systemctl daemon-reload
}

configure_advanced_options()
{
    logit
    logit "Configuring advanced options..."

    if [ "$BEHIND_NAT" = "yes" ]
    then
        echo "org.ice4j.ice.harvest.NAT_HARVESTER_LOCAL_ADDRESS="$PRIVATE_IP""|sudo tee -a /etc/jitsi/videobridge/sip-communicator.properties  > /dev/null
    
        echo "org.ice4j.ice.harvest.NAT_HARVESTER_PUBLIC_ADDRESS="$PUBLIC_IP""|sudo tee -a /etc/jitsi/videobridge/sip-communicator.properties  > /dev/null
    
        sudo sed -i 's/.*org.ice4j.ice.harvest.STUN_MAPPING_HARVESTER_ADDRESSES/# org.ice4j.ice.harvest.STUN_MAPPING_HARVESTER_ADDRESSES/' /etc/jitsi/videobridge/sip-communicator.properties
    fi

    modify_systemd_limits
    
    logit "Configuring advanced options: COMPLETE..."
    logit
}

secure_domain_register_users()
{
    logit
    logit "Registering users in prosody..."
    logit "These accounts can be used to join a meeting as a host..."
    logit

    #check if accounts were added in config file
    num_users=0
    if [ -n "$SECURE_USERS" ] && [ -n "$SECURE_PASSWORDS" ]
    then
        #user/password details found in config file
        for user in $SECURE_USERS
        do
            users+=($user)
        done
        logit "For Secure Domain - Number of users in config file: ${#users[@]}"

        for password in $SECURE_PASSWORDS
        do
            passwords+=($password)
        done
        logit "For Secure Domain - Number of passwords in config file: ${#passwords[@]}"

        if [ "${#users[@]}" -lt "${#passwords[@]}" ]
        then
            num_users="${#users[@]}"
        else
            num_users="${#passwords[@]}"
        fi

        logit; logit "For Secure Domain - Will register $num_users user(s) in prosody..."; logit
    fi

    i=0
    while true
    do
        if [ $i -lt $num_users ]
        then
            read username password dump < <(echo ${users[$i]} ${passwords[$i]})
            ((i++))
            if [ $i -eq $num_users ]
            then
                logit "For Secure Domain - All $num_users user(s) configured in prosody..."
                break
            fi
        else
            #Not using logit because we have -n here
            echo -n "Choose an account name: "|tee -a "$LOGFILE"
            read -r username
            logit
            echo -n "Choose password for $username: "|tee -a "$LOGFILE"

            while true; do
                read -N 1 -s character
                [ "${character}" == $'\n' ] && break
                echo -n "*" >&2|tee -a "$LOGFILE"
                password="${password}${character}"
            done

            logit
            logit
        fi

        logit "Registering $username in prosody now..."
        sudo prosodyctl register "$username" "$SERVER_FQDN" "$password"
        [ $? = 0 ] && logit "Registered user '$username'...You may use this for starting a meeting..." ||
            logit "*** ERROR ***: prosodyctl - Error registering user '$user' to $SERVER_FQDN"

        logit

        if [ $num_users -eq 0 ]
        then

            logit "Do you want to add another account?"

            select yn in "Yes" "No"; do
                logit "You chose: \"$REPLY\""
                case $REPLY in
                    1|[yY]|[Yy][Ee][Ss]) logit
                        logit "OK. Let's add one more account..."
                        password=""
                        logit
                        break;;
                    2|[nN]|[Nn][Oo]) logit
                        logit "OK. No more accounts...got it...";
                        logit
                        break 2;;
                    *)  logit
                        logit "Invalid option...Choose one from given options..."; ;;
                esac
            done #select end
        fi

    done #while end
}

# With this setup, the host will need to authenticate to join in a meeting.
# Guest users can join anonymously
configure_secure_domain()
{
    logit
    logit "Configuring Secure Domain..."
    logit

    PROSODY_FILE=/etc/prosody/conf.avail/"$SERVER_FQDN".cfg.lua
    
    #Modify to internal_hashed if needed
    sudo sed -i 's/authentication = "anonymous"/authentication = "internal_plain"/' "$PROSODY_FILE"
    sudo sed -i "/VirtualHost \"auth.$SERVER_FQDN\"/i VirtualHost \"guest.$SERVER_FQDN\"\n\tauthentication = \"anonymous\"\n\tc2s_require_encryption = false\n" "$PROSODY_FILE"

    JITSI_MEET_CONFIG=/etc/jitsi/meet/"$SERVER_FQDN"-config.js
    sudo sed -i "s/.*anonymousdomain.*/\tanonymousdomain: \'guest.$SERVER_FQDN\',/" /etc/jitsi/meet/*js "$JITSI_MEET_CONFIG"

    echo "org.jitsi.jicofo.auth.URL=XMPP:$SERVER_FQDN" | sudo tee -a /etc/jitsi/jicofo/sip-communicator.properties > /dev/null

    secure_domain_register_users
    
    SECURE_DOMAIN_CONFIGURED=1

    logit
    logit "Configuring Secure Domain: COMPLETE..."
    logit
}

check_configure_secure_domain()
{
    case "$ENABLE_SECURE_DOMAIN" in
    "yes")
        logit "Found ENABLE_SECURE_DOMAIN=yes in config file..."
        logit "Proceeding to configure secure domain..."
        configure_secure_domain
        return
        ;;
    "no")
        logit "Found ENABLE_SECURE_DOMAIN=no in config file..."
        logit "SKIPPING secure domain..."
        return
        ;;
    *)  logit "ENABLE_SECURE_DOMAIN not found in config...will prompt now..."; logit
        ;;
    esac

logit
    logit "Secure Domain: Once configured, the host has to authenticate using username/password for joining a meeting..."
    logit "It is RECOMMENDED as a security measure..."
    logit
    logit "Do you want to configure secure domain?"
    logit
    select yn in "Yes" "No"; do
    logit "You chose: \"$REPLY\""
    case $REPLY in
        1|[yY]|[Yy][Ee][Ss]) logit 
            logit "OK. Proceeding to configure secure domain..." 
            configure_secure_domain
            break;;
        2|[nN]|[Nn][Oo]) logit
            logit "OK. SKIPPING secure domain..."; break;;
        *)  logit
            logit "Invalid option...Choose one from given options..."; ;;
    esac
    done
}

generate_letsencrypt_certs()
{
    if [ -z "$LETSENCRYPT_EMAIL" ]
    then
      sudo /usr/share/jitsi-meet/scripts/install-letsencrypt-cert.sh
    else
        echo "$LETSENCRYPT_EMAIL" | sudo /usr/share/jitsi-meet/scripts/install-letsencrypt-cert.sh
    fi

    logit
    logit "*********************************************************************"
    logit "Certificate generation SUCCESS...Good...OR..."
    logit
    logit "OR...Let's Encrypt certificate generation FAILED?"
    logit "Do not worry, self-signed certificates will be used instead..."
    logit "Proceeding with install..."
    logit "*********************************************************************"
    logit
}

check_generate_letsencrypt_certs()
{

    case "$GENERATE_LETSENCRYPT_CERTS" in
    "yes")
        logit; logit "Found GENERATE_LETSENCRYPT_CERTS=yes in config file..."
        logit "Proceeding to generate Let's Encrypt certificates..."
        generate_letsencrypt_certs
        return
        ;;
    "no")
        logit; logit "Found GENERATE_LETSENCRYPT_CERTS=no in config file..."
        logit "SKIPPING Let's Encrypt certificates... self-signed certificates will be used..."
        return
        ;;
    *)  logit
        logit "GENERATE_LETSENCRYPT_CERTS not found in config...will prompt now..."; logit
        ;;
    esac

    logit
    logit "For encryption, Let's Encrypt certificates are RECOMMENDED than self-signed certificates..."
    logit
    logit "Do you want to generate Let's Encrypt certificates?"
    logit
    select yn in "Yes" "No"; do
    logit "You chose: \"$REPLY\""
    case $REPLY in
        1|[yY]|[Yy][Ee][Ss]) logit 
            logit "OK. Proceeding to generate Let's Encrypt certificates..."
            logit 
            generate_letsencrypt_certs
            break;;
        2|[nN]|[Nn][Oo]) logit
            logit "OK. SKIPPING Let's Encrypt certificates... self-signed certificates will be used instead..."
            break;;
        *)  logit
            logit "Invalid option...Choose one from given options..."; ;;
    esac
    done
}

install_jitsi_meet()
{
    logit 
    logit "Installing jitsi-meet..."
    
    sudo apt install wget curl -y

    install_latest_prosody 
    configure_firewall

    sudo apt-get update
    sudo apt install gnupg2 -y
    sudo apt install nginx-full -y

    sudo apt update
    sudo apt install apt-transport-https -y
    
    if [ "$OS_DISTRO" = "Ubuntu" ]
    then
        sudo apt-add-repository universe -y
        sudo apt update
    fi

    sudo apt install openjdk-8-jdk -y

    #set hostname
    sudo hostnamectl set-hostname "$HOST_NAME"

    #insert domain in /etc/hosts
    sudo sed -i "1i $LOCALHOST $SERVER_FQDN $HOST_NAME" /etc/hosts

    curl https://download.jitsi.org/jitsi-key.gpg.key | sudo sh -c 'gpg --dearmor > /usr/share/keyrings/jitsi-keyring.gpg'
    echo 'deb [signed-by=/usr/share/keyrings/jitsi-keyring.gpg] https://download.jitsi.org stable/' | sudo tee /etc/apt/sources.list.d/jitsi-stable.list > /dev/null

    # update all package sources
    sudo apt update
    # jitsi-meet installation
    echo "jitsi-videobridge2 jitsi-videobridge/jvb-hostname string $SERVER_FQDN" | sudo debconf-set-selections
    echo "jitsi-meet-web-config jitsi-meet/cert-choice select 'Generate a new self-signed certificate (You will later get a chance to obtain a Let's encrypt certificate)'" | sudo debconf-set-selections
    #sudo apt-get --option=Dpkg::Options::=--force-confold --option=Dpkg::options::=--force-unsafe-io --assume-yes --quiet install jitsi-meet
    sudo apt install jitsi-meet -y

    JITSI_MEET_INSTALLED=1
    
    logit 
    logit "jitsi-meet Installation: COMPLETE..."
}

# TODO: check if this should be mandatory when secure domain is configured
enable_jigasi_authentication()
{
    logit
    logit "Enabling Authentication for jigasi..."

    JIGASI_SIP_COMM_FILE=/etc/jitsi/jigasi/sip-communicator.properties

    #JIGASI_USER=$(< /dev/urandom tr -dc a-z0-9 | head -c10)
    JIGASI_USER="transcriber"

    JIGASI_PASSWORD=$(< /dev/urandom tr -dc a-z0-9 | head -c10)
    
    #Add a new domain in prodosy
    #Modify to internal_hashed if needed
    echo -e "\nVirtualHost \"$HIDDEN_DOMAIN\"\n\tauthentication = \"internal_plain\"\n\tc2s_require_encryption = false"|sudo tee -a /etc/prosody/conf.d/"$SERVER_FQDN".cfg.lua > /dev/null

    #Register this domain so that transcriber joins hidden
    sudo prosodyctl register "$JIGASI_USER" "$HIDDEN_DOMAIN" "$JIGASI_PASSWORD"
    [ $? = 0 ] && logit "Registered user '$JIGASI_USER'..." ||
            logit "*** ERROR ***: prosodyctl - Error registering user '$JIGASI_USER' to $HIDDEN_DOMAIN"
    
    sudo sed -i "s/^#.*org.jitsi.jigasi.xmpp.acc.USER_ID=.*/org.jitsi.jigasi.xmpp.acc.USER_ID="$JIGASI_USER"@"$HIDDEN_DOMAIN"/" "$JIGASI_SIP_COMM_FILE"
    sudo sed -i "s/^#.*org.jitsi.jigasi.xmpp.acc.PASS=.*/org.jitsi.jigasi.xmpp.acc.PASS="$JIGASI_PASSWORD"/" "$JIGASI_SIP_COMM_FILE"
    sudo sed -i 's/^#.*org.jitsi.jigasi.xmpp.acc.ANONYMOUS_AUTH=.*/org.jitsi.jigasi.xmpp.acc.ANONYMOUS_AUTH=false/' "$JIGASI_SIP_COMM_FILE"

    #Also allow non secure connections to xmpp(for self-signed certs, I think)
    sudo sed -i '/org.jitsi.jigasi.xmpp.acc.USER_ID=/i org.jitsi.jigasi.xmpp.acc.ALLOW_NON_SECURE=true' "$JIGASI_SIP_COMM_FILE"

    logit "Enabling Authentication for jigasi: COMPLETE..."
    logit
}

check_enable_jigasi_authentication()
{
    case "$ENABLE_JIGASI_AUTHENTICATION" in
    "yes")
        logit "Found ENABLE_JIGASI_AUTHENTICATION=yes in config file..."
        logit "Proceeding with Jigasi Authentication..."
        enable_jigasi_authentication
        return
        ;;
    "no")
        logit "Found ENABLE_JIGASI_AUTHENTICATION=no in config file..."
        logit "SKIPPING Jigasi Authentication..."
        return
        ;;
    *)  logit "ENABLE_JIGASI_AUTHENTICATION not found in config...will prompt now...";
        logit
        ;;
    esac

    logit "Jigasi Authentication is RECOMMENDED, so that transcriber (Speech-To-Text) joins in hidden mode..."
    logit
    logit "Do you want to configure authentication for jigasi?"
    
    select yn in "Yes" "No"; do
    logit "You chose: \"$REPLY\""
    case $REPLY in
        1|[yY]|[Yy][Ee][Ss]) logit 
            logit "OK. Proceeding with Jigasi Authentication..."; 
            enable_jigasi_authentication 
            break
            ;;
        2|[nN]|[Nn][Oo]) logit
            logit "OK. SKIPPING Jigasi Authentication..."; 
            break 
            ;;
        *)  logit
            logit "Invalid option...Choose one from given options..."
            ;;
    esac
    done
}

use_google_transcription()
{
    logit
    logit "Configuring \"Google\" Transcription (Speech-To-Text) Engine..."
    logit
    
    #Changes in Jigasi
    sudo touch "$ACTUAL_GOOGLE_CREDS_PATH"
    sudo chown jigasi:jitsi "$ACTUAL_GOOGLE_CREDS_PATH"

    if [ -r "$GOOGLE_APPLICATION_CREDENTIALS" ]
    then
        logit "Copying Google Credentials from "$GOOGLE_APPLICATION_CREDENTIALS" to "$ACTUAL_GOOGLE_CREDS_PATH""
        sudo cp "$GOOGLE_APPLICATION_CREDENTIALS" "$ACTUAL_GOOGLE_CREDS_PATH"
    fi

    echo "GOOGLE_APPLICATION_CREDENTIALS=$ACTUAL_GOOGLE_CREDS_PATH"|sudo tee -a /etc/jitsi/jigasi/config > /dev/null

    logit
    logit "Configuring \"Google\" Transcription (Speech-To-Text) Engine: COMPLETE..."
    logit
}

use_vosk_transcription()
{
    logit
    logit "Configuring \"Vosk\" Transcription (Speech-To-Text) Engine..."
    logit
    
    JIGASI_SIP_COMM_FILE=/etc/jitsi/jigasi/sip-communicator.properties
    sudo sed -i 's/^#.*org.jitsi.jigasi.transcription.customService=/org.jitsi.jigasi.transcription.customService=/' $JIGASI_SIP_COMM_FILE
    sudo sed -i 's/^#.*org.jitsi.jigasi.transcription.vosk.websocket_url=/org.jitsi.jigasi.transcription.vosk.websocket_url=/' $JIGASI_SIP_COMM_FILE

    logit "Configuring \"Vosk\" Transcription (Speech-To-Text) Engine: COMPLETE..."
    logit
    logit "*** You may choose a different webocket URL instead of localhost... If you choose to, modify \"org.jitsi.jigasi.transcription.vosk.websocket_url\" in $JIGASI_SIP_COMM_FILE ***"
    logit
}

# TODO: Handle case insensitive TRANSCRIPTION_ENGINE from config file
choose_transcription_engine()
{
    logit
    logit "Now that you have basic settings in place, choose a Transcription (Speech-To-Text) Engine..."
    
    #selected in config file?
    if [ -n "$TRANSCRIPTION_ENGINE" ]
    then
        logit; logit "TRANSCRIPTION_ENGINE found in config file: \"$TRANSCRIPTION_ENGINE\""
        case "$TRANSCRIPTION_ENGINE" in
            "google")
                logit
                logit "OK. Proceeding to configure Google's Transcription (Speech-To-Text) Engine...";
                use_google_transcription
                return
                ;;

            "vosk")
                logit
                logit "OK. Proceeding to configure Vosk's Transcription (Speech-To-Text) Engine...";
                use_vosk_transcription
                return
                ;;
            *)
                logit
                logit "*** WARNING ***: Invalid TRANSCRIPTION_ENGINE \"$TRANSCRIPTION_ENGINE\" in config file..."
                logit
                ;;
        esac
    fi

    select engine in "Google" "Vosk"; do
    logit "You chose: \"$REPLY. $engine\""
    case $REPLY in
        1) logit 
            logit "OK. Proceeding to configure Google's Transcription (Speech-To-Text) Engine..."; 
            use_google_transcription
            break
            ;;
        2) logit
            logit "OK. Proceeding to configure Vosk's Transcription (Speech-To-Text) Engine..."; 
            use_vosk_transcription
            break 
            ;;
        *)  logit
            logit "Invalid option...Choose one from given options..."
            ;;
    esac
    done
}

configure_transcription()
{
    logit
    logit "Configuring Transcription (Speech-To-Text)..."
    logit

    INTERFACE_CONFIG="/usr/share/jitsi-meet/interface_config.js"

    #This should be by default. Adding to be safer.
    sudo sed -i "s/.*DISABLE_TRANSCRIPTION_SUBTITLES:.*/    DISABLE_TRANSCRIPTION_SUBTITLES: false,/" $INTERFACE_CONFIG

    #Make sure 'closedcaptions' is present in TOOLBAR_BUTTONS in "/usr/share/jitsi-meet/interface_config.js"
    #This is present by default. Added here to check to make sure in case of any issues.

    #Changes in jitsi-meet
    sudo sed -i "s/.*\/\/.*transcribingEnabled: .*/\ttranscribingEnabled: true,\n\thiddenDomain: '$HIDDEN_DOMAIN',/" /etc/jitsi/meet/"$SERVER_FQDN"-config.js 
    
    PROSODY_FILE=/etc/prosody/conf.avail/"$SERVER_FQDN".cfg.lua
    
    #whitelist transcriber to join lobby
    sudo sed -i "s/.*muc_lobby_whitelist = {/    muc_lobby_whitelist = { \"$HIDDEN_DOMAIN\",/" "$PROSODY_FILE"
    
    JIGASI_SIP_COMM_FILE=/etc/jitsi/jigasi/sip-communicator.properties
    sudo sed -i 's/^#.*org.jitsi.jigasi.ENABLE_TRANSCRIPTION=.*/org.jitsi.jigasi.ENABLE_TRANSCRIPTION=true/' $JIGASI_SIP_COMM_FILE
    sudo sed -i 's/^#.*org.jitsi.jigasi.ENABLE_SIP=.*/org.jitsi.jigasi.ENABLE_SIP=true/' $JIGASI_SIP_COMM_FILE
    [ ! -d "$JIGASI_TRANSCRIPTS_DIR" ] &&
        sudo mkdir -p "$JIGASI_TRANSCRIPTS_DIR" &&
        logit "Created Jigasi Transcripts Directory $JIGASI_TRANSCRIPTS_DIR" ||
        logit "Jigasi Transcripts Directory $JIGASI_TRANSCRIPTS_DIR: Already exists..."
    
    sudo chown jigasi:jitsi "$JIGASI_TRANSCRIPTS_DIR"
    
    #Different separator(|) as the directory $JIGASI_TRANSCRIPTS_DIR may contain a '/'
    sudo sed -i "s|^#.*org.jitsi.jigasi.transcription.DIRECTORY=.*|org.jitsi.jigasi.transcription.DIRECTORY=$JIGASI_TRANSCRIPTS_DIR|" $JIGASI_SIP_COMM_FILE
    
    sudo sed -i 's/^#.*org.jitsi.jigasi.transcription.BASE_URL=/org.jitsi.jigasi.transcription.BASE_URL=/' $JIGASI_SIP_COMM_FILE
    sudo sed -i 's/^#.*org.jitsi.jigasi.transcription.jetty.port=/org.jitsi.jigasi.transcription.jetty.port=/' $JIGASI_SIP_COMM_FILE
    sudo sed -i 's/^#.*org.jitsi.jigasi.transcription.ADVERTISE_URL=.*/org.jitsi.jigasi.transcription.ADVERTISE_URL=false/' $JIGASI_SIP_COMM_FILE
    
    sudo sed -i 's/^#.*net.java.sip.communicator.service.gui.ALWAYS_TRUST_MODE_ENABLED=.*/net.java.sip.communicator.service.gui.ALWAYS_TRUST_MODE_ENABLED=true/' $JIGASI_SIP_COMM_FILE
    
    sudo sed -i 's/^#.*org.jitsi.jigasi.transcription.SAVE_JSON=.*/org.jitsi.jigasi.transcription.SAVE_JSON=false/' $JIGASI_SIP_COMM_FILE
    sudo sed -i 's/^#.*org.jitsi.jigasi.transcription.SAVE_TXT=.*/org.jitsi.jigasi.transcription.SAVE_TXT=true/' $JIGASI_SIP_COMM_FILE
    
    sudo sed -i 's/^#.*org.jitsi.jigasi.transcription.SEND_JSON=.*/org.jitsi.jigasi.transcription.SEND_JSON=true/' $JIGASI_SIP_COMM_FILE
    sudo sed -i 's/^#.*org.jitsi.jigasi.transcription.SEND_TXT=.*/org.jitsi.jigasi.transcription.SEND_TXT=false/' $JIGASI_SIP_COMM_FILE
    
    logit
    logit "Configuring Transcription (Speech-To-Text): Basic configuration COMPLETE..."
    logit

    choose_transcription_engine
}

check_configure_transcription()
{
    case "$ENABLE_TRANSCRIPTION" in
    "yes")
        logit "Found ENABLE_TRANSCRIPTION=yes in config file..."
        logit "Proceeding to configure Transcription (Speech-To-Text)..."
        configure_transcription
        return
        ;;
    "no")
        logit "Found ENABLE_TRANSCRIPTION=no in config file..."
        logit "SKIPPING Transcription (Speech-To-Text)..."
        return
        ;;
    *)
        logit "ENABLE_TRANSCRIPTION not found in config...will prompt now..."; logit
        ;;
    esac

    logit
    logit "Do you want to configure Transcription (Speech-To-Text)?"
    
    select yn in "Yes" "No"; do
    logit "You chose: \"$REPLY\""
    case $REPLY in
        1|[yY]|[Yy][Ee][Ss]) logit 
            logit "OK. Proceeding to configure Transcription (Speech-To-Text)..."; 
            configure_transcription 
            break
            ;;
        2|[nN]|[Nn][Oo]) logit
            logit "OK. SKIPPING Transcription (Speech-To-Text)..."; 
            break 
            ;;
        *)  logit
            logit "Invalid option...Choose one from given options..."
            ;;
    esac
    done
}

configure_jibri_conf()
{
    logit
    logit "Configuring jibri.conf now..."

    JIBRI_CONF="/etc/jitsi/jibri/jibri.conf"
    
    #TODO: Add variables for certs(like self-signed/letsencrypt/use existing certificate)
    SELF_SIGNED_CERTS="yes"
    if [ "$SELF_SIGNED_CERTS" = "yes" ]
    then
        IGNORE_CERTIFICATE_ERRORS="\"--ignore-certificate-errors\","
    fi
    
    MY_JIBRI_ID=$(< /dev/urandom tr -dc a-zA-Z | head -c10)

    sudo sh -c "cat > $JIBRI_CONF << EOF
jibri {
  // A unique identifier for this Jibri
  // TODO: eventually this will be required with no default
  id = \"jibri-$MY_JIBRI_ID\"
  // Whether or not Jibri should return to idle state after handling
  // (successfully or unsuccessfully) a request.  A value of 'true'
  // here means that a Jibri will NOT return back to the IDLE state
  // and will need to be restarted in order to be used again.
  single-use-mode = false
  api {
    http {
      external-api-port = 2222
      internal-api-port = 3333
    }
    xmpp {
      // See example_xmpp_envs.conf for an example of what is expected here
      environments = [
        {
            // A user-friendly name for this environment
            name = \"xmpp environment\"

            // A list of XMPP server hosts to which we'll connect
            xmpp-server-hosts = [ \"$SERVER_FQDN\" ]

            // The base XMPP domain
            xmpp-domain = \"$SERVER_FQDN\"

            // The MUC we'll join to announce our presence for
            // recording and streaming services
            control-muc {
                domain = \"internal.auth.$SERVER_FQDN\"
                room-name = \"JibriBrewery\"
                nickname = \"jibri\"
            }

            // The login information for the control MUC
            control-login {
                domain = \"auth.$SERVER_FQDN\"
                username = \"jibri\"
                password = \"$JIBRI_AUTH_PASSWORD\"
            }

            // An (optional) MUC configuration where we'll
            // join to announce SIP gateway services
            // sip-control-muc {
               // domain = "domain"
               // room-name = "room-name"
               // nickname = "nickname"
            // }

            // The login information the selenium web client will use
            call-login {
                domain = \"$HIDDEN_DOMAIN\"
                username = \"recorder\"
                password = \"$JIBRI_RECORDER_PASSWORD\"
            }

            // The value we'll strip from the room JID domain to derive
            // the call URL
            strip-from-room-domain = \"conference.\"

            // How long Jibri sessions will be allowed to last before
            // they are stopped.  A value of 0 allows them to go on
            // indefinitely
            usage-timeout = \"1 hour\"

            // Whether or not we'll automatically trust any cert on
            // this XMPP domain
            trust-all-xmpp-certs = true
        }
    ]
    }
  }
  recording {
    recordings-directory = \"$JIBRI_RECORDINGS_DIR\"
    # TODO: make this an optional param and remove the default
    finalize-script = \"\"
  }
  streaming {
    // A list of regex patterns for allowed RTMP URLs.  The RTMP URL used
    // when starting a stream must match at least one of the patterns in
    // this list.
    rtmp-allow-list = [
      // By default, all services are allowed
      \".*\"
    ]
  }
  chrome {
    // The flags which will be passed to chromium when launching
    flags = [
      \"--use-fake-ui-for-media-stream\",
      $IGNORE_CERTIFICATE_ERRORS
      \"--start-maximized\",
      \"--kiosk\",
      \"--enabled\",
      \"--disable-infobars\",
      \"--autoplay-policy=no-user-gesture-required\"
    ]
  }
  stats {
    enable-stats-d = true
  }
  webhook {
    // A list of subscribers interested in receiving webhook events
    subscribers = []
  }
  jwt-info {
    // The path to a .pem file which will be used to sign JWT tokens used in webhook
    // requests.  If not set, no JWT will be added to webhook requests.
    # signing-key-path = \"/path/to/key.pem\"

    // The kid to use as part of the JWT
    # kid = \"key-id\"

    // The issuer of the JWT
    # issuer = \"issuer\"

    // The audience of the JWT
    # audience = \"audience\"

    // The TTL of each generated JWT.  Can't be less than 10 minutes.
    # ttl = 1 hour
  }
  call-status-checks {
    // If all clients have their audio and video muted and if Jibri does not
    // detect any data stream (audio or video) comming in, it will stop
    // recording after NO_MEDIA_TIMEOUT expires.
    no-media-timeout = 30 seconds

    // If all clients have their audio and video muted, Jibri consideres this
    // as an empty call and stops the recording after ALL_MUTED_TIMEOUT expires.
    all-muted-timeout = 10 minutes

    // When detecting if a call is empty, Jibri takes into consideration for how
    // long the call has been empty already. If it has been empty for more than
    // DEFAULT_CALL_EMPTY_TIMEOUT, it will consider it empty and stop the recording.
    default-call-empty-timeout = 30 seconds
  }
}
EOF
"
    logit "Configuring jibri.conf: COMPLETE..."
    logit
}

jibri_configure_jitsi_meet()
{
    logit
    logit "Configuring jibri now..."
    logit
    
    sudo usermod -aG adm,audio,video,plugdev jibri
    
    [ ! -d "$JIBRI_RECORDINGS_DIR" ] &&
        sudo mkdir -p "$JIBRI_RECORDINGS_DIR" && 
        logit "Created Jibri Recordings Directory $JIBRI_RECORDINGS_DIR" ||
        logit "Jibri Recordings Directory $JIBRI_RECORDINGS_DIR: Already exists..."
        
    sudo chown jibri:jibri "$JIBRI_RECORDINGS_DIR"
    
    PROSODY_FILE=/etc/prosody/conf.avail/"$SERVER_FQDN".cfg.lua
    
    sudo sed  -i "/Component \"internal.auth.$SERVER_FQDN\"/a \ \tmuc_room_cache_size = 1000" "$PROSODY_FILE"
    
    #TODO: Duplicate if transcription is enabled? Check if this needs to be removed!
    echo -e "\nVirtualHost \"$HIDDEN_DOMAIN\"\n\tauthentication = \"internal_plain\"\n\tc2s_require_encryption = false\n\tmodules_enabled = {\n\t    \"ping\";\n\t}"|sudo tee -a "$PROSODY_FILE" > /dev/null

    #whitelist recorder to join lobby (should be present by default, this is extra check)
    sudo sed -i "s/.*muc_lobby_whitelist = {/    muc_lobby_whitelist = { \"$HIDDEN_DOMAIN\",/" "$PROSODY_FILE"
    
    JIBRI_AUTH_PASSWORD=$(< /dev/urandom tr -dc a-z0-9 | head -c10)
    JIBRI_RECORDER_PASSWORD=$(< /dev/urandom tr -dc a-z0-9 | head -c10)
    
    sudo prosodyctl register jibri auth."$SERVER_FQDN" "$JIBRI_AUTH_PASSWORD"
    [ $? = 0 ] && logit "Registered user 'jibri'..." ||
            logit "*** ERROR ***: prosodyctl - Error registering user 'jibri' to auth."$SERVER_FQDN""
    
    sudo prosodyctl register recorder "$HIDDEN_DOMAIN" "$JIBRI_RECORDER_PASSWORD"
    [ $? = 0 ] && logit "Registered user 'recorder'..." ||
            logit "*** ERROR ***: prosodyctl - Error registering user 'recorder' to $HIDDEN_DOMAIN"

    JICOFO_SIP_FILE="/etc/jitsi/jicofo/sip-communicator.properties"
    echo "org.jitsi.jicofo.jibri.BREWERY=JibriBrewery@internal.auth.$SERVER_FQDN" | sudo tee -a "$JICOFO_SIP_FILE" > /dev/null
    echo "org.jitsi.jicofo.jibri.PENDING_TIMEOUT=90" | sudo tee -a "$JICOFO_SIP_FILE" > /dev/null
    
    JITSI_MEET_CONFIG=/etc/jitsi/meet/"$SERVER_FQDN"-config.js
    
    sudo sed -i "s/.*fileRecordingsEnabled:.*/    fileRecordingsEnabled: true,/" "$JITSI_MEET_CONFIG"
    sudo sed -i "s/.*liveStreamingEnabled:.*/    liveStreamingEnabled: true,/" "$JITSI_MEET_CONFIG"
    sudo sed -i "/liveStreamingEnabled: true/a hiddenDomain: '$HIDDEN_DOMAIN'," "$JITSI_MEET_CONFIG"

    #Make sure TOOLBAR_BUTTONS array, in "/usr/share/jitsi-meet/interface_config.js", contains the recording value if you want to show the file recording button
    #This should be present by default. Added here to check to make sure in case of any issues.

    #Make sure TOOLBAR_BUTTONS array, in "/usr/share/jitsi-meet/interface_config.js", livestreaming value if you want to show the live streaming button
    #This should be present by default. Added here to check to make sure in case of any issues.
    
    logit
    logit "Configuring jibri: COMPLETE..."
    logit
}

# java8 is recommended for jibri as it is optimized for this version
# java11 works too, but jibri is not optimized for this version yet
install_and_use_java8()
{
    logit
    logit "Installing java-8..."
    logit
    
    #java8 is deprecated for debian-10. This seems to be a work around...
    if [ "$OS_DISTRO" = "Debian" ]
    then
        wget -O - https://adoptopenjdk.jfrog.io/adoptopenjdk/api/gpg/key/public | sudo apt-key add -
        sudo add-apt-repository https://adoptopenjdk.jfrog.io/adoptopenjdk/deb/
        sudo apt update
        sudo apt install adoptopenjdk-8-hotspot -y
        JAVA8="/usr/lib/jvm/adoptopenjdk-8-hotspot-amd64/bin/java"
    fi

    if [ "$OS_DISTRO" = "Ubuntu" ]
    then
        sudo apt install openjdk-8-jdk -y
        JAVA8="/usr/lib/jvm/java-8-openjdk-amd64/jre/bin/java"
    fi
    
    logit; logit "java8 path is: $JAVA8"

    logit
    logit "Installing java-8: COMPLETE..."
    logit

    sudo sed -i "s|java |$JAVA8 |" /opt/jitsi/jibri/launch.sh
}

# Log a warning if chromer_version is older than that of chromedriver
check_chrome_chromedriver_compatibility()
{
    logit "Running compatibility check..."; logit
    logit "$(google-chrome --version)"
    logit "$(chromedriver --version)"
    logit

    chrome_version=$(google-chrome --version|cut -d' ' -f3)
    chromedriver_version=$(chromedriver --version|cut -d' ' -f 2)

    if [ -n "$chrome_version" ] && [ -n "$chromedriver_version" ]
    then
        version_compare "$chrome_version" "$chromedriver_version" &&
            logit "*** WARNING ***: ChromeDriver is newer than Chrome.
                It may not support this version of Chrome. Better if both are of same version..." ||
            logit "Chrome and ChromeDriver are compatible..."
    else
        logit "*** ERROR ***: Either Chrome or ChromeDriver(or both) is(are) not installed..."
        logit "*** ERROR ***: Recording will not start..."
    fi
}

#install compatible versions
install_chrome_and_chromedriver()
{
    logit; logit "Installing stable version of Google Chrome..."; logit

    logit "Uninstalling Chrome if already installed..."
    sudo apt purge google-chrome-stable* -y

    #Google Chrome stable
    curl -sS -o - https://dl-ssl.google.com/linux/linux_signing_key.pub | sudo apt-key add
    echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" | sudo tee -a /etc/apt/sources.list.d/google-chrome.list
    sudo apt-get -y update
    sudo apt-get -y install google-chrome-stable

    sudo mkdir -p /etc/opt/chrome/policies/managed
    grep -qs '{ "CommandLineFlagSecurityWarningsEnabled": false }' /etc/opt/chrome/policies/managed/managed_policies.json
    if [ $? != 0 ]
    then
        logit; logit "Chrome policies: Added \"CommandLineFlagSecurityWarningsEnabled\": false"
        echo '{ "CommandLineFlagSecurityWarningsEnabled": false }' | sudo tee -a /etc/opt/chrome/policies/managed/managed_policies.json > /dev/null
    else
        logit; logit "Chrome policies: Already present - \"CommandLineFlagSecurityWarningsEnabled\": false"
    fi

    logit; logit "Google Chrome Stable build Install COMPLETE..."; logit
    logit "Google Chrome version installed: $(google-chrome --version)"; logit

    logit "Installing compatible Google ChromeDriver now...";

    #Chromedriver
    #Remove if already present
    chromedriver=$(which chromedriver)
    sudo rm -f "$chromedriver"

    #Now install the compatible version
    chrome_version=$(google-chrome --version|cut -d' ' -f3)
    STABLE_CHROMEENGINE=$(echo "$chrome_version"| cut -d. -f1,2,3)

    #fetch stable release, that is compatible with chrome stable version that is installed
    CHROME_DRIVER_VERSION=$(curl -sS chromedriver.storage.googleapis.com/LATEST_RELEASE_$STABLE_CHROMEENGINE)

    wget -N http://chromedriver.storage.googleapis.com/$CHROME_DRIVER_VERSION/chromedriver_linux64.zip -P ~/
    unzip ~/chromedriver_linux64.zip -d ~/
    rm ~/chromedriver_linux64.zip
    sudo mv -f ~/chromedriver /usr/local/bin/chromedriver
    sudo chown root:root /usr/local/bin/chromedriver
    sudo chmod 0755 /usr/local/bin/chromedriver

    logit; logit "Chromedriver install COMPLETE..."; logit
    logit "ChromeDriver version installed: $(chromedriver --version|cut -d' ' -f 2)"; logit
}

# Returns 0(SUCCESS), if all requisites are successfully installed
# Returns 1(FAILURE), if it failed to install any
install_jibri_prerequisites()
{
    logit
    logit "Installing Prerequisites for jibri..."
    logit

    #ALSA and Loopback Device
    grep snd-aloop /etc/modules > /dev/null || echo "snd-aloop" | sudo tee -a /etc/modules > /dev/null
    sudo modprobe snd-aloop
    
    #exit in case of errors with snd-aloop module
    if ! sudo lsmod | grep snd_aloop > /dev/null
    then
        logit "*** ERROR ***: \"sudo lsmod | grep snd_aloop\" Failed..."
        logit "*** ERROR ***: FATAL: Module snd-aloop not found..."
        logit; logit "*** Current kernel: $(uname -r) ***"; logit
        logit "*** TIP ***: Select generic kernel instead of aws/cloud(DigitalOcean)..."
        logit "*** ERROR ***: Correct it and Rerun the setup..."

        return 1
    fi

    logit; logit "ALSA and Loopback Device configured..."; logit
    
    sudo apt install linux-image-amd64 curl unzip software-properties-common -y
    sudo apt install curl unzip wget -y

    #This is need only for Ubuntu-14(trusty)
    #Ffmpeg with X11 capture support
    #only checking if version is less than Ubuntu-16
    if [ "$OS_DISTRO" = "Ubuntu" ] && version_compare "$OS_RELEASE" "$MIN_UBUNTU_RELEASE"
    then
        logit "Operating System: $(lsb_release -ds)"
        logit "Ubuntu-Trusty version detected...Installing Ffmpeg for Trusty now..."
        sudo add-apt-repository ppa:mc3man/trusty-media -y
        sudo apt-get update -y
        sudo apt-get install ffmpeg -y
        logit; logit "Ffmpeg install for Ubuntu-Trusty COMPLETE..."; logit
    fi
    
    install_chrome_and_chromedriver
    
    #Extra check to make sure both versions are compatibe
    check_chrome_chromedriver_compatibility

    logit; logit "Installing Miscellaneous packages..."; logit
    #Miscellaneous packages
    sudo apt-get install default-jre-headless ffmpeg alsa-utils icewm xdotool xserver-xorg-input-void xserver-xorg-video-dummy -y
    logit "Installing Miscellaneous packages: COMPLETE..."; logit

    logit
    logit "Installing Prerequisites for jibri: COMPLETE..."
    logit

    return 0
}

install_jibri()
{
    logit 
    logit "Installing jibri..."
    logit
    
    if ! install_jibri_prerequisites
    then
        logit
        logit "*** ERROR ***: Encountered error in prerequisites for jibri..."
        logit "*** ERROR ***: Cannot proceed further with installation of jibri..."
        logit "*** Will continue without it... Sleeping for 10 seconds hoping you would notice this message ***"
        #sleep a little so that user can notice this message
        sleep 10
        logit
        return
    fi

    logit; logit "Installing jibri now..."; logit

    #Jibri
    wget -qO - https://download.jitsi.org/jitsi-key.gpg.key | sudo apt-key add -
    sudo sh -c "echo 'deb https://download.jitsi.org stable/' > /etc/apt/sources.list.d/jitsi-stable.list"
    sudo apt-get update

    sudo apt-get install jibri

    JIBRI_INSTALLED=1 
    
    logit 
    logit "jibri Installation: COMPLETE..."
    logit

    install_and_use_java8

    jibri_configure_jitsi_meet

    configure_jibri_conf

    sudo systemctl enable jibri
}

check_install_jibri()
{
    case "$INSTALL_JIBRI" in
    "yes")
        logit "Found INSTALL_JIBRI=yes in config file..."
        logit "Proceeding to install Jibri.."
        install_jibri
        return
        ;;
    "no")
        logit; logit "Found INSTALL_JIBRI=no in config file..."
        logit "SKIPPING Jibri Installation..."
        return
        ;;
    *)  logit "INSTALL_JIBRI not found in config...will prompt now..."; logit
        ;;
    esac

    logit
    logit "Do you want to install Jibri?"
    
    select yn in "Yes" "No"; do
    logit "You chose: \"$REPLY\""
    case $REPLY in
        1|[yY]|[Yy][Ee][Ss]) logit 
            logit "OK. Proceeding to install Jibri..."; 
            install_jibri;
            break
            ;;
        2|[nN]|[Nn][Oo]) logit
            logit "OK. SKIPPING Jibri Installation..."; 
            break 
            ;;
        *) logit
            logit "Invalid option...Choose one from given options..."
            ;;
    esac
    done
}

# Returns 0(SUCCESS) if minimum requirement is met
# Returns 1(FAILURE) if not
check_os_requirement_for_jigasi()
{
    #For jigasi, a package 'ruby-hocon' is needed
    #This is a Debian-10(buster) package
    #Hence Jigasi cannot be installed on Debian-9(stretch)
    #Supported only on Debian-10(buster) and future releases

    MIN_DEBIAN_FOR_JIGASI=10
    if [ "$OS_DISTRO" = "Debian" ] && version_compare "$OS_RELEASE" "$MIN_DEBIAN_FOR_JIGASI"
    then
        logit
        logit "Operating System check for Jigasi..."
        logit "*** WARNING ***: Debian-9 detected...Jigasi depends on a package 'ruby-hocon'"
        logit "*** WARNING ***: That package cannot be installed on Debian-9..."
        logit "*** WARNING ***: Jigasi cannot be installed on this platform..."
        logit
        return 1
   fi

   return 0
}

install_jigasi()
{
    logit 
 
    if ! check_os_requirement_for_jigasi
    then
        logit "*** ERROR ***: Not going to install jigasi..."
        return 1
    fi
    
    logit "Installing jigasi..."
    
    if [ -n "$SIP_USER_ID" ] && [ -n "$SIP_PASSWORD" ]
    then 
        logit "SIP Details already set..."
        logit
        echo "jigasi jigasi/sip-account string $SIP_USER_ID" | sudo debconf-set-selections
        echo "jigasi jigasi/sip-password password $SIP_PASSWORD" | sudo debconf-set-selections
        sudo apt install jigasi -y
    else
        logit "All SIP Details not set..."
        logit
        sudo apt install jigasi
    fi

    #comment out BOSH_URL_PATTERN so that Transcriptions and SIP callouts can work
    #They have been failing without this, with error "room is null"
    #TODO: May need to be removed in future if we find what the issue with BOSH is
    sudo sed -i -e '/BOSH_URL_PATTERN/s/net.java.sip.communicator.impl.protocol.jabber./#net.java.sip.communicator.impl.protocol.jabber./' /etc/jitsi/jigasi/sip-communicator.properties

    JIGASI_INSTALLED=1 

    logit "jigasi Installation: COMPLETE..."
    logit

    return 0
}

check_install_jigasi()
{
    case "$INSTALL_JIGASI" in
    "yes")
        logit "Found INSTALL_JIGASI=yes in config file..."
        logit "Proceeding to install Jigasi.."
        install_jigasi
        return
        ;;
    "no")
        logit "Found INSTALL_JIGASI=no in config file..."
        logit "OK. SKIPPING Jigasi Installation..."
        return
        ;;
    *)  logit "INSTALL_JIGASI not found in config...will prompt now..."; logit
        ;;
    esac

    logit
    logit "Do you want to install Jigasi?"
    
    select yn in "Yes" "No"; do
    logit "You chose: \"$REPLY\""
    case $REPLY in
        1|[yY]|[Yy][Ee][Ss]) logit 
            logit "OK. Proceeding to install Jigasi..."; 
            install_jigasi 
            break
            ;;
        2|[nN]|[Nn][Oo]) logit
            logit "OK. SKIPPING Jigasi Installation..."; 
            break 
            ;;
        *) logit
            logit "Invalid option...Choose one from given options..."
            ;;
    esac
    done
}

# Return 0(SUCCESS) if installed. 1 if not
is_jigasi_installed()
{
    dpkg -l|grep -i jigasi > /dev/null
    if [ $? = 0 ]
    then 
        #logit "Jigasi is already installed..."
        return 0
    else
        #logit "Jigasi is not installed..."
        return 1
    fi
}

# Return 0(SUCCESS) if installed. 1 if not
is_jibri_installed()
{
    dpkg -l|grep -i jibri > /dev/null
    if [ $? = 0 ]
    then 
        #logit "Jibri is already installed..."
        return 0
    else
        #logit "Jibri is not installed..."
        return 1
    fi
}

configure_etherpad_jitsi()
{
    logit
    logit "Making configuration changes in Jitsi for Etherpad..."

    ETHERPAD_BASE="https://$SERVER_FQDN/etherpad/p/"

    JITSI_MEET_CONFIG="/etc/jitsi/meet/"$SERVER_FQDN"-config.js"
    NGINX_CONF="/etc/nginx/sites-available/"$SERVER_FQDN".conf"

    sudo sed -i "/List of undocumented settings used in lib-jitsi-meet/i     etherpad_base: \'$ETHERPAD_BASE\',\n" $JITSI_MEET_CONFIG

    ETHERPAD_NGINX_BLOCK="    \# Etherpad-lite\n    location ^~ /etherpad/ {\n        proxy_pass http://localhost:9001/;\n        proxy_set_header X-Forwarded-For \$remote_addr;\n        proxy_buffering off;\n        proxy_set_header Host \$host;\n    }\n\n    \# websockets for subdomains"
        #sed -i "s|.*websockets for subdomains|    \# Etherpad-lite\n    location ^~ /etherpad/ {\n        proxy_pass http://localhost:9001/;\n        proxy_set_header X-Forwarded-For \$remote_addr;\n        proxy_buffering off;\n        proxy_set_header Host \$host;\n    }\n\n    \# websockets for subdomains|" $NGINX_CONF

    sudo sed -i "s|.*websockets for subdomains|$ETHERPAD_NGINX_BLOCK|" $NGINX_CONF

    logit "Making configuration changes in Jitsi for Etherpad: COMPLETE..."
    logit
}

configure_etherpad_service()
{
    logit
    logit "Configuring Etherpad as a service..."

    sudo adduser --system --home=$ETHERPAD_INSTALL_DIR/etherpad-lite/ --group etherpad
    sudo chown -R etherpad: $ETHERPAD_INSTALL_DIR

    ETHERPAD_SERVICE_FILE="/etc/init.d/etherpad-lite"

    sudo sh -c "cat > $ETHERPAD_SERVICE_FILE << 'EOF'
#!/bin/sh

### BEGIN INIT INFO
# Provides:          etherpad-lite
# Required-Start:    \$local_fs \$remote_fs \$network \$syslog
# Required-Stop:     \$local_fs \$remote_fs \$network \$syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: starts etherpad lite
# Description:       starts etherpad lite using start-stop-daemon
### END INIT INFO

PATH=\"/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/opt/node/bin\"
LOGFILE=\"/home/ubuntu/etherpad/etherpad-lite.log\"
EPLITE_DIR=\"/home/ubuntu/etherpad/etherpad-lite\"
EPLITE_BIN=\"bin/safeRun.sh\"
USER=\"etherpad\"
GROUP=\"etherpad\"
DESC=\"Etherpad Lite\"
NAME=\"etherpad-lite\"

set -e

. /lib/lsb/init-functions

start() {
  echo \"Starting \$DESC... \"

    start-stop-daemon --start --chuid \"\$USER:\$GROUP\" --background --make-pidfile --pidfile /var/run/\$NAME.pid --exec \$EPLITE_DIR/\$EPLITE_BIN -- \$LOGFILE || true
  echo \"done\"
}

#We need this function to ensure the whole process tree will be killed
killtree() {
    local _pid=\$1
    local _sig=\${2-TERM}
    for _child in \$(ps -o pid --no-headers --ppid \${_pid}); do
        killtree \${_child} \${_sig}
    done
    kill -\${_sig} \${_pid}
}

stop() {
  echo \"Stopping \$DESC... \"
   while test -d /proc/\$(cat /var/run/\$NAME.pid); do
    killtree \$(cat /var/run/\$NAME.pid) 15
    sleep 0.5
  done
  rm /var/run/\$NAME.pid
  echo \"done\"
}

status() {
  status_of_proc -p /var/run/\$NAME.pid \"\" \"etherpad-lite\" && exit 0 || exit \$?
}

case \"\$1\" in
  start)
      start
      ;;
  stop)
      stop
      ;;
  restart)
      stop
      start
      ;;
  status)
      status
      ;;
  *)
      echo \"Usage: \$NAME {start|stop|restart|status}\" >&2
      exit 1
      ;;
esac

exit 0
EOF
"

    sudo chmod +x /etc/init.d/etherpad-lite
    sudo update-rc.d etherpad-lite defaults

    logit
    logit "Configuring Etherpad as a service: COMPLETE..."
    logit
}

install_etherpad_extra_features()
{
    logit
    logit "Installing Extra features of Etherpad..."
    logit

    cd $ETHERPAD_INSTALL_DIR/etherpad-lite

    npm install --no-save --legacy-peer-deps ep_headings2 ep_markdown ep_comments_page ep_align ep_font_color ep_webrtc ep_embedded_hyperlinks2

    DISABLE_AUDIO_VIDEO="\  \"ep_webrtc\" : {\n      \"enabled\": false,\n      \"audio\" : {\n          \"disabled\": \"soft\"\n      },\n      \"video\" : {\n          \"disabled\": \"soft\"\n      }\n  },\n"

    sudo -i sed "/\"port\": 9001,/a $DISABLE_AUDIO_VIDEO" settings.json

    logit
    logit "Installing Extra features of Etherpad: COMPLETE..."
    logit
}

install_etherpad()
{
    logit
    logit "Installing Etherpad..."
    logit

    MIN_NODEJS_VERSION="10.17.0"

    sudo apt install npm -y
    sudo apt install nodejs -y

    NODEJS_VERSION=$(nodejs --version)
    logit "Version of nodejs: $NODEJS_VERSION"
    if version_compare ${NODEJS_VERSION:1} $MIN_NODEJS_VERSION
    then
        logit "*** WARNING ***: Nodejs: $NODEJS_VERSION. Minimum version recommended $MIN_NODEJS_VERSION..."
        logit "Not going to install Etherpad..."
        return
    fi

    mkdir -p $ETHERPAD_INSTALL_DIR
    cd $ETHERPAD_INSTALL_DIR
    git clone --branch master https://github.com/ether/etherpad-lite.git

    install_etherpad_extra_features

    configure_etherpad_service

    configure_etherpad_jitsi

    logit "Starting Etherpad service..."
    sudo systemctl start etherpad-lite
    logit "Starting Etherpad service: COMPLETE..."
    logit

    logit "Installing Etherpad: COMPLETE..."
    logit
}

check_install_etherpad()
{
    case "$INSTALL_ETHERPAD" in
    "yes")
        logit "Found INSTALL_ETHERPAD=yes in config file..."
        logit "Proceeding to install Etherpad..."
        install_etherpad
        return
        ;;
    "no")
        logit "Found INSTALL_ETHERPAD=no in config file..."
        logit "OK. SKIPPING ETHERPAD Installation..."
        return
        ;;
    *)  logit "INSTALL_ETHERPAD not found in config...will prompt now..."; logit
        ;;
    esac

    logit
    logit "Do you want to install Etherpad (https://github.com/ether/etherpad-lite)?"

    select yn in "Yes" "No"; do
    logit "You chose: \"$REPLY\""
    case $REPLY in
        1|[yY]|[Yy][Ee][Ss]) logit
            logit "OK. Proceeding to install Etherpad...";
            install_etherpad
            break
            ;;
        2|[nN]|[Nn][Oo]) logit
            logit "OK. SKIPPING Etherpad Installation...";
            break
            ;;
        *) logit
            logit "Invalid option...Choose one from given options..."
            ;;
    esac
    done

}

install_jitsi()
{
    #check for previously installed versions
    dpkg -l|grep -E "nginx-full|jitsi|jigasi|jibri" > /dev/null
    if [ $? -eq 0 ]
    then 

        logit "Found already installed versions..."
        logit "Make sure you have UNINSTALLED first and then run install..."
        logit "Proceed with install now?"

        select yn in "Yes" "No" "Quit"; do
            logit "You chose: \"$REPLY\""
            case $REPLY in
                1|[yY]|[Yy][Ee][Ss]) logit; logit "OK. Proceeding..."; logit; break;;
                2|[nN]|[Nn][Oo]) logit; logit "Run with uninstall and then install"; show_end_time; exit;;
                3|[qQ]|[Qq][Uu][Ii][Tt]) logit; logit "Quitting..."; show_end_time; exit;;
                *) logit "Invalid option...Choose one from given options..."; ;;
            esac
        done
    fi
    
    check_prerequisites
    
    install_jitsi_meet

    #Generate Let's Encrypt Certificates?
    check_generate_letsencrypt_certs
    
    configure_advanced_options

    #configure secure domain?
    check_configure_secure_domain
    
    #Install Etherpad and integrate with jitsi?
    check_install_etherpad

    #Install Jigasi?
    check_install_jigasi

    if is_jigasi_installed
    then
        #Enable Jigasi Authentication?
        check_enable_jigasi_authentication

        #Configure Transcription (Speech-To-Text)?
        check_configure_transcription
    fi

    #Install Jibri?
    check_install_jibri
    
    logit
    logit "**********************************"
    logit "$PRODUCT_NAME: Install COMPLETE..."
    logit "**********************************"
    logit

    show_installed_versions

    sudo sed -i 's/server_names_hash_bucket_size 64/server_names_hash_bucket_size 100/' /etc/nginx/sites-available/"$SERVER_FQDN".conf

    logit "Restarting services so you can join meetings..."
    restart_services

    show_service_status
}

uninstall_jitsi()
{
    logit "Starting to uninstall..."

    stop_services
    logit
    
    kill_lingering_processes
    logit

    #Begin uninstall
    logit
    logit "Purging services..."
    sudo apt purge jibri jigasi jitsi-meet jitsi-meet-web-config jitsi-meet-prosody jitsi-meet-turnserver jitsi-meet-web jicofo jitsi-videobridge2 nginx nginx-full -y
    sudo apt purge prosody -y
    sudo apt purge nginx nginx-common -y

    #Documentation says "Sometimes the following packages will fail to uninstall properly"
    #Hence, to be safer, run it for second time
    sudo apt purge jigasi jitsi-videobridge2 -y
    
    #Remove directories
    remove_old_directories
    
    #Remove entry inserted at the time of installation
    : ${HOST_NAME:="$HOSTNAME"} #default to $HOSTNAME if null
    sudo sed -i "/^$LOCALHOST $SERVER_FQDN $HOST_NAME$/d" /etc/hosts

    logit
    logit "**********************************"
    logit "$PRODUCT_NAME: Uninstall COMPLETE..."
    logit "**********************************"
    logit
    
    logit "Showing installed services after uninstall, for verification(should not see any services)..."
    show_installed_versions
}

check_uninstall()
{
    if [ "$UNINSTALL_WITHOUT_PROMPT" = "yes" ]
    then
        logit "Found UNINSTALL_WITHOUT_PROMPT=yes in config file..."
        logit "Proceeding to Uninstall, without prompting yes/no..."
        uninstall_jitsi
        return;
    fi

    logit
    logit "This will uninstall all jitsi components, nginx, jitsi-meet, jicofo, jitsi-videobridge, Jigasi, jibri"
    logit "*** NOTE ***: This will also remove all directories listed below:"
    logit
    logit -n $'\t\t'
    logit  "$TO_REMOVE_DIRS"
    logit
    logit "Quit here if you want to make copies of any of those directories..."
    logit
    logit "Do you REALLY want to uninstall?"
    select yn in "Yes" "No" "Quit"; do
    logit "You chose: \"$REPLY\""
    case $REPLY in
        1|[yY]|[Yy][Ee][Ss]) logit; logit "OK. Uninstalling..."; 
                             uninstall_jitsi
                             break;;
        2|[nN]|[Nn][Oo]) logit; logit "OK...Not going to uninstall..."; return;;
        3|[qQ]|[Qq][Uu][Ii][Tt]) logit; logit "Quitting Uninstall..."; return;;
        *) logit "Invalid option...Choose one from given options..."; ;;
    esac
    done
}

# TODO: Might add a check to verify the SIP user_id format(user@host) for jigasi
check_configuration()
{
    logit "Checking Configuration..."

    logit
    logit "Mandatory configuration options:

    0. BEHIND_NAT (Set it to \"no\" if the server has a public IP on one of it's interfaces, else to \"yes\")
    1. SERVER_FQDN (This will be used to access the web conferences)
    2. PUBLIC_IP (mandatory only if BEHIND_NAT is \"yes\")
    3. PRIVATE_IP (mandatory only if BEHIND_NAT is \"yes\")

    For other options, dump the config file template using \"export_config_file_template\" option and check..."

    logit
    emptyenv=0

    logit
    logit "*** $PRODUCT_NAME: Configuration for this run would be: ***"
    logit

    if [ -z "$BEHIND_NAT" ] 
    then
        logit "***** BEHIND_NAT not set(mandatory)..."
        logit "Set it to \"no\", if the server has a public IP assigned on one of it's interfaces...
          \"yes\", otherwise..."
        
        logit "***** Set it using export SERVER_FQDN=yes/no"
        emptyenv=1
    else
        if [ "$BEHIND_NAT" != "yes" ] && [ "$BEHIND_NAT" != "no" ]
        then
            logit "***** BEHIND_NAT not set to correct value(mandatory)...set it to either \"yes\" or \"no\""
            emptyenv=1
        else
            logit "BEHIND_NAT=$BEHIND_NAT"
        fi
    fi
    
    logit

    if [ -z "$SERVER_FQDN" ] 
    then
        logit "***** SERVER_FQDN not set(mandatory). Set it using export SERVER_FQDN=FQDN_OF_SERVER"
        emptyenv=1
    else
        logit "SERVER_FQDN=$SERVER_FQDN"
    fi
    
    logit
    
    if [ "$BEHIND_NAT" = "yes" ]
    then
        if [ -z "$PUBLIC_IP" ] 
            then
                logit "***** Server is behind NAT. PUBLIC_IP is mandatory..."
                logit "***** PUBLIC_IP not set(mandatory). Set it using export PUBLIC_IP=IP"
                emptyenv=1
        else
            logit "PUBLIC_IP=$PUBLIC_IP"
        fi
        
        logit

        if  [ -z "$PRIVATE_IP" ]
        then
            logit "***** Server is behind NAT. PRIVATE_IP is mandatory..."
            logit "***** PRIVATE_IP not set(mandatory). Set it using export PRIVATE_IP=IP"
            emptyenv=1
        else
            logit "PRIVATE_IP=$PRIVATE_IP"
        fi
    fi
    
    logit

    if [ -z "$HOST_NAME" ] 
    then
        logit "HOST_NAME not set. Defaulting to the current hostname \"$(hostname)\""
        HOST_NAME=$(hostname)
    else
        logit "HOST_NAME=$HOST_NAME"
    fi
    
    logit
    
    if [ -z "$GOOGLE_APPLICATION_CREDENTIALS" ]
    then
        logit "GOOGLE_APPLICATION_CREDENTIALS not set. Will copy from default $DEFAULT_GOOGLE_CREDS_PATH (if exists)"
        GOOGLE_APPLICATION_CREDENTIALS=$DEFAULT_GOOGLE_CREDS_PATH
    else
        logit "GOOGLE_APPLICATION_CREDENTIALS=$GOOGLE_APPLICATION_CREDENTIALS"
    fi
    
    logit
    
    if [ -z "$JIGASI_TRANSCRIPTS_DIR" ]
    then
        logit "JIGASI_TRANSCRIPTS_DIR not set. Defaulting to $DEFAULT_JIGASI_TRANSCRIPTS_DIR"
        JIGASI_TRANSCRIPTS_DIR="$DEFAULT_JIGASI_TRANSCRIPTS_DIR"
    else
        logit "JIGASI_TRANSCRIPTS_DIR=$JIGASI_TRANSCRIPTS_DIR"
        logit "*** NOTE ***: Transcripts directory is set. It's owner:group will be changed to jigasi:jitsi"
    fi
    
    if [ "$JIGASI_TRANSCRIPTS_DIR" = "$DEFAULT_JIGASI_TRANSCRIPTS_DIR" ]
    then
        logit "*** NOTE ***: Remember to take a backup of $JIGASI_TRANSCRIPTS_DIR before uninstalling..."
    fi
    
    logit

    if [ -z "$JIBRI_RECORDINGS_DIR" ]
    then
        logit "JIBRI_RECORDINGS_DIR not set. Defaulting to $DEFAULT_JIBRI_RECORDINGS_DIR"
        JIBRI_RECORDINGS_DIR="$DEFAULT_JIBRI_RECORDINGS_DIR"
    else
        logit "JIBRI_RECORDINGS_DIR=$JIBRI_RECORDINGS_DIR"
        logit "*** NOTE ***: Recordings directory is set. It's owner:group will be changed to jibri:jibri"
    fi
    
    if [ "$JIBRI_RECORDINGS_DIR" = "$DEFAULT_JIBRI_RECORDINGS_DIR" ]
    then
        logit "*** NOTE ***: Remember to take a backup of $JIBRI_RECORDINGS_DIR before uninstalling..."
    fi
    
    logit
    
    if [ -z "$SIP_USER_ID" ]
    then
        logit "SIP_USER_ID is not set. You will be asked to enter while installing jigasi..."
    else
        logit "SIP_USER_ID=$SIP_USER_ID"
    fi
    
    logit
    
    if [ -z "$SIP_PASSWORD" ]
    then
        logit "SIP_PASSWORD is not set. You will be asked to enter while installing jigasi..."
    else
        logit "SIP_PASSWORD=$SIP_PASSWORD"
    fi
    
    logit
    
    if [ $emptyenv -eq 1 ]
    then
        logit "***** Prerequisites: ***** FAIL *****. Set all the mandatory configuration options..."
        logit "***** Either export them from Terminal... OR..."
        logit "***** Use Configuration file $CONFIG_FILE"
        logit "***** You may dump the config file template using \"export_config_file_template\" option..."
        logit
        show_end_time
        exit
    else
        logit "Prerequisites: ***** PASS *****. All mandatory configuration options are in place..."
        logit
    fi
    
    logit

    logit "TODO: Run IP validations for both private and public..."
    logit
}

check_os()
{
    MIN_UBUNTU_RELEASE="18.04"
    MIN_DEBIAN_RELEASE="9"

    logit "Checking Operating System..."

    logit
    logit "$(lsb_release -i)"
    logit "$(lsb_release -d)"
    logit "$(lsb_release -r)"
    logit "$(lsb_release -c)"

    logit
    logit "Kernel: $(uname -rmso)"
    logit

    #TODO: Exit if OS min requirement is not met?
    if [ "$OS_DISTRO" = "Ubuntu" ]
    then 
        version_compare "$OS_RELEASE" "$MIN_UBUNTU_RELEASE" && 
            logit "*** WARNING ***: $OS_DISTRO: Minimum version recommended $MIN_UBUNTU_RELEASE"
    fi

    #TODO: Exit if OS min requirement is not met?
    if [ "$OS_DISTRO" = "Debian" ] 
    then
        version_compare "$OS_RELEASE" "$MIN_DEBIAN_RELEASE" && 
            logit "*** WARNING ***: $OS_DISTRO: Minimum version recommended $MIN_DEBIAN_RELEASE"
    fi
    
    check_os_requirement_for_jigasi

    logit "$OS_DISTRO-$OS_RELEASE: Operating System Check *** All Good ***"
    logit
}

check_prerequisites()
{
    logit
    logit "Checking Prerequisites..."
    logit

    check_os
    
    check_configuration

    #Do any other prerequisite checks here...

    logit
    logit "Checking Prerequisites: COMPLETE..."
    logit
}

usage()
{
    logit "*** Run it either as root user or a user with sudo privileges ***"
    logit
    logit "Usage:"
    logit
    logit "./$SCRIPT_NAME (*** Run without any arguments ***)"
    logit
    logit "Supports: [check_prerequisites|show_installed_versions|install|uninstall|help|export_config_file_template|show_status_of_services|Quit]"
    logit
    logit "1. check_prerequisites: Check if all prerequisites are met, like mandatory configuration options"
    logit "2. show_installed_versions: Display versions of all jitsi software(s)"
    logit "3. install: Will install all jitsi components listed below
            nginx, jitsi-meet, prosody, jicofo, jitsi-videobridge, jigasi, jibri"
    logit "4. uninstall: Will stop services & uninstall all jitsi components listed below
            nginx, jitsi-meet, prosody, jicofo, jitsi-videobridge, jigasi, jibri"

    logit "5. help: Display help/usage"
	logit "6. export_config_file_template: Dump configuration file template to current directory" 
    logit "7. show_status_of_services: Displays status(running or not) of all jitsi software(s)"
    logit "8. Quit: Quit setup"

    logit
    logit "*** NOTE ***: uninstall will also remove all the directories listed below: "
    logit
    logit -n $'\t\t'
    logit  "$TO_REMOVE_DIRS"
    logit
}

check_lock()
{
    if [ -f "$LOCKFILE" ]
    then
        logit "ALERT: Script is already running. If not, you may delete the lock file $LOCKFILE and run this again. Exiting now..."
        logit
        exit
    fi
}

release_lock()
{
    sudo rm -f "$LOCKFILE"
    logit "$PRODUCT_NAME: Lock Released...You are good for next run..."
    logit
}

# This is needed for latest features of jitsi like lobby
# 0.11 is needed at least for lobby
install_latest_prosody()
{
    logit
    logit "Installing latest version of prosody..."

    echo deb http://packages.prosody.im/debian $(lsb_release -sc) main | sudo tee -a /etc/apt/sources.list
    wget https://prosody.im/files/prosody-debian-packages.key -O- | sudo apt-key add -

    sudo apt-get update
    sudo apt-get install prosody -y

    logit "Prosody updated to latest version...Below is the version currently installed..."
    logit
    dpkg -l|grep prosody|tee -a "$LOGFILE"
    logit
}

export_config_file_template()
{
    if [ ! -f "$CONFIG_FILE" ]
    then
        logit "Exporting config file template to $CONFIG_FILE"

        sudo sh -c "cat > $CONFIG_FILE << EOF
# Configuration for "$PRODUCT_NAME" installer
# Version: "$SCRIPT_VERSION"

# Mandatory parameters
# BEHIND_NAT=yes/no
# SERVER_FQDN=\"FQDN of the server\"

# Private and Public IPs are mandatory, only if BEHIND_NAT=yes
# PUBLIC_IP=\"server's public ip\"
# PRIVATE_IP=\"server's private ip\"

# Mandatory parameters end

# HOST_NAME=\"hostname of the server\" #result of command 'hostname'

# Certificates
# USE_SELF_SIGNED_CERTS=yes/no
# GENERATE_LETSENCRYPT_CERTS=yes/no
# USE_EXISTING_CERTS=yes/no
# 
# LETSENCRYPT_EMAIL=DummyName@DummyCompany
# 
# For Jitsi Meet Server
# ENABLE_SECURE_DOMAIN=yes/no
# 
# Ensure that the number of users and the number of passwords are same
# SECURE_USERS=\"user1 user2 user3 ...\"
# SECURE_PASSWORDS=\"password1 password2 password3 ...\"

# INSTALL_ETHERPAD=yes/no

# For Jigasi
# INSTALL_JIGASI=yes/no
# ENABLE_JIGASI_AUTHENTICATION=yes/no
# 
# Should be of format USER@HOST
# SIP_USER_ID=SIPUSER@SIPHOST
# SIP_PASSWORD=PASSWORD_FOR_SIPUSER
# 
# For Transcription
# ENABLE_TRANSCRIPTION=yes/no
# JIGASI_TRANSCRIPTS_DIR=/directory/to/store/transcripts
# 
# TRANSCRIPTION_ENGINE=google/vosk #case sensitive
# GOOGLE_APPLICATION_CREDENTIALS=/path/to/google/credentials/file
# 
# For Jibri
# INSTALL_JIBRI=yes/no
# JIBRI_RECORDINGS_DIR=/directory/to/store/recordings
# 
# Miscellaneous
# UNINSTALL_WITHOUT_PROMPT=yes/no
EOF
"
        sudo chown "$CURRENT_USER":"$CURRENT_USER" "$CONFIG_FILE"
        logit "Exporting config file template to $CONFIG_FILE: COMPLETE..."
        logit
    else
        logit "Config file $CONFIG_FILE already exists...Not overwriting it with template..."
        logit
    fi
}

# Will be read if the file is present in same directory as the script
# Will take precedence over the environment variables set from Terminal
# Returns 0 if read was successful
# Returns 1 if file was not in proper format
read_config_file()
{
    if [ -r "$CONFIG_FILE" ]
    then
        logit
        logit "*** Config file found: $CONFIG_FILE"

        #check if it is alright
        if bash -n $CONFIG_FILE > /dev/null 2>&1
        then
            source "$CONFIG_FILE"
            logit "*** Reading config file now..."
            logit
            while read line
            do
                #[[ "$line" =~ ^#.*$ ]] && continue
                #[[ "$line" =~ ^$ ]] && continue

                line=$(echo $line|sed 's/#.*//')
                [[ "$line" =~ ^$ ]] && continue

                logit "${FUNCNAME[0]}: $line" "nostdout"
            done <  $CONFIG_FILE

            logit
            logit "*** Reading configuration from $CONFIG_FILE: COMPLETE... ***"
        else
            logit "*** ERROR ***: Config file $CONFIG_FILE is not in proper format..."
            logit "*** ERROR ***: Correct it and rerun...Exiting now..."
            return 1
        fi
        logit
    else
        logit
        logit "*** Config file $CONFIG_FILE Not found... ***"
        logit "*** You may add all configurations to $CONFIG_FILE and rerun ***"
        logit
    fi

    return 0
}

# TODO: check permissions for log directory and /tmp(for locking)
check_permissions()
{
    mkdir -p "$LOGDIR"
}

# Execution starts here (MAIN)

check_permissions

logit
logit "**********************************************************"
logit "            	$PRODUCT_NAME - $SCRIPT_VERSION"
logit "**********************************************************"
logit "Installer for jitsi-meet, jigasi and jibri on same server"
logit
logit "Supported Platforms: Ubuntu-16/18/20, Debian-9/10"
logit "**********************************************************"

trap release_lock SIGINT
# trap release_lock SIGTERM

show_start_time

check_lock

# Acquire lock now
sudo touch "$LOCKFILE"
echo "$(date)"|sudo tee -a "$LOCKFILE" > /dev/null

logit "$PRODUCT_NAME: Lock Acquired..."
logit

if [ $# -gt 1 ]
then
    logit "*** Simply run without any parameters... ***"
    usage | less
    show_end_time
    exit
fi

# This is the default path if GOOGLE_APPLICATION_CREDENTIALS option is not set
# This path is needed for Speech-To-Text configuration
DEFAULT_GOOGLE_CREDS_PATH="$HOME/google_credentials.json"

# If GOOGLE_APPLICATION_CREDENTIALS is set, that file will be copied here
# And this will be used while configuring
ACTUAL_GOOGLE_CREDS_PATH="/etc/jitsi/jigasi/google_credentials.json"

DEFAULT_JIGASI_TRANSCRIPTS_DIR=/etc/"$PRODUCT_NAME"/transcripts
DEFAULT_JIBRI_RECORDINGS_DIR=/etc/"$PRODUCT_NAME"/recordings

ETHERPAD_INSTALL_DIR="$HOME/etherpad"

# To track installed components
JITSI_MEET_INSTALLED=0
JIGASI_INSTALLED=0
JIBRI_INSTALLED=0

SECURE_DOMAIN_CONFIGURED=0

# Domain for Transcriber/Recorder
# This domain should be configured to be hidden, so that Transcriber/Recorder joins hidden
HIDDEN_DOMAIN="$PRODUCT_NAME.hiddendomain.com"

# This will be added in /etc/hosts for resolving $SERVER_FQDN while installing
# Will be removed while uninstalling
LOCALHOST="127.0.0.1"

PS3="$PRODUCT_NAME - Choice: "

logit "*** Welcome to $PRODUCT_NAME setup ***"

if ! read_config_file
then
    show_end_time
    exit
fi

logit "What do you want to do?"

# Display Menu
logit "
    1) check_prerequisites          5) Uninstall
    2) show_installed_versions      6) help
    3) show_status_of_services      7) export_config_file_template
    4) Install                      8) Quit
"

echo -n "$PS3"

if [ -n "$1" ]
then
    chosen_setup_option="$1"
else
    read chosen_setup_option
fi

logit "You chose: \"$chosen_setup_option\""

case "$chosen_setup_option" in 

1)
    check_prerequisites | less
    ;;

2)
    show_installed_versions
    ;;

3)
    logit
    show_service_status
    ;;
4)
    logit
    logit "$SCRIPT_NAME Install called..."

    show_installed_versions

    install_jitsi
    post_install_tasks

    install_aliases
    ;;

5)
    logit
    logit "$SCRIPT_NAME Uninstall called..."
    show_installed_versions
    check_uninstall
    ;;

6)
    logit
    usage |less
    ;;

7)
    logit
    export_config_file_template
    ;;

8)
    logit
    logit "Quitting..."
    ;;

*)
    logit
    logit "$SCRIPT_NAME: Invalid option \"$chosen_setup_option\"...Choose one from given options..."
    logit
    ;;
esac

show_end_time
