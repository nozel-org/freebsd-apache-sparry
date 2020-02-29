#!/bin/sh

#############################################################################
# Version 0.1.0-UNSTABLE (29-02-2020)
#############################################################################

#############################################################################
# Copyright 2016-2020 Nozel/Sebas Veeke. Licenced under a Creative Commons
# Attribution-NonCommercial-ShareAlike 4.0 International License.
#
# See https://creativecommons.org/licenses/by-nc-sa/4.0/
#
# Contact:
# > e-mail      mail@nozel.org
# > GitHub      nozel-org
#############################################################################

#############################################################################
# VARIABLES
#############################################################################

# remindbot version
WEBOT_VERSION='0.1.0'

# apache parameters
APACHE_CONFIG_DIRECTORY='/usr/local/etc/apache24/Includes'

# FUNCTIONS
# - create new apache configuration file
# --- insert domain
# ------ with or without www?
# --- with or without security headers?
# --- what profile (1: general, 2: wp etc.)
# ------if true, special security headers for Wordpress?
# --- with or without TLS-certificate?
# ------ if true, then check DNS
# --------- if true, request certificate
# --- if succesful, restart apache

# LIMITATIONS
# It's only compatible with default packages/ports and default apache directories and stuff
# - only basic stuff is possible, so for example only 1 domain (with www as subdomain) per config file/cert.

# NOTES
# - makes config per domain
# - doesn't harden base apache or base lets encrypt configuration

# FUTURE
# - maybe add auto harden feature? (apache, TLS/certbot etc.)
# - Add option for self-signed cert?

#############################################################################
# ARGUMENTS
#############################################################################

# save amount of arguments for validity check
#ARGUMENTS="${#}"

# populate validation variables with zero
ARGUMENT_OPTION='0'
ARGUMENT_FEATURE='0'
ARGUMENT_METHOD='0'

# enable help, version and a cli option
while test -n "$1"; do
    case "$1" in
        # options
        --version|-v)
            ARGUMENT_VERSION='1'
            shift
            ;;

        --help|help|-h)
            ARGUMENT_HELP='1'
            shift
            ;;

        # features
        --add-webconfig|-a)
            ARGUMENT_ADD_WEBCONFIG='1'
            shift
            ;;

        # other
        *)
            ARGUMENT_NONE='1'
            shift
            ;;
    esac
done

#############################################################################
# ERROR FUNCTIONS
#############################################################################

# argument errors
error_invalid_option() {
    echo 'webot: invalid argument'
    echo "Use 'webot --help' for a list of valid arguments."
    exit 1
}

error_wrong_amount_of_arguments() {
    echo 'webot: wrong amount of arguments'
    echo "Use 'webot --help' for a list of valid arguments."
    exit 1
}

# requirement errors
error_os_not_supported() {
    echo 'webot: operating system is not supported.'
    exit 1
}

error_apache_not_installed() {
    echo 'webot: apache not installed'
    echo "use 'pkg install apache24' or install apache from ports."
    exit 1
}

error_certbot_not_installed() {
    echo 'webot: certbot not installed'
    echo "use 'pkg install py37-certbot py37-certbot-apache' or install certbot from ports."
}

error_no_root_privileges() {
    echo 'webot: you need to be root to perform this command'
    echo "use 'sudo webot', 'sudo -s' or run webot as root user."
    exit 1
}

error_no_internet_connection() {
    echo 'webot: access to the internet is required.'
    exit 1
}

# feature errors
error_type_yes_or_no() {
    echo '[ ! ] webot: type yes or no and press enter to continue.'
}

error_type_valid_number() {
    echo '[ ! ] webot: type a valid number and press enter to continue.'
}

error_dns_required() {
    echo '[ ! ] webot: propagated DNS required, please configure DNS first.'
    exit 1
}

error_invalid_domain() {
    echo '[ ! ] webot: invalid domain, please add a valid domain. A valid domain:'
    echo ' - consists of domain.tld or subdomain.domain.tld.'
    echo ' - can be reached from this server (nameservers and records).'
}

#############################################################################
# REQUIREMENT FUNCTIONS
#############################################################################

requirement_argument_validity() {
    # show error when amount of arguments is not equal to one
    #if [ "$#" -eq 0 ]; then
    #    error_wrong_amount_of_arguments
    #fi
    echo "hoi"
}

requirement_root() {
    # show error when webot has no root privileges
    if [ "$(id -u)" -ne 0 ]; then
        error_no_root_privileges
    fi
}

requirement_os() {
    # show error when freebsd-version cannot be found (which probably means the user isn't running FreeBSD)
    if [ ! "$(command -v freebsd-version)" ]; then
        error_os_not_supported
    fi
}

requirement_apache() {
    # show error when apachectl cannot be found (which probably means the user has not installed apache)
    if [ ! "$(command -v apachectl)" ]; then
        error_apache_not_installed
    fi
}

requirement_certbot() {
    # show error when apachectl cannot be found (which probably means the user has not installed apache)
    if [ ! "$(command -v certbot)" ]; then
        error_apache_not_installed
    fi
}

requirement_internet() {
    # check internet connection
    if ! nc -zw2 google.com 443 2>/dev/null; then
        error_no_internet_connection
    fi
}

# CHECK OM DUBBELE CONFIGS TE VOORKOMEN

#############################################################################
# MANAGEMENT FUNCTIONS
#############################################################################

webot_version() {
    echo "webot ${WEBOT_VERSION}"
    echo "Copyright (C) 2019-2020 Nozel."
    echo "License CC Attribution-NonCommercial-ShareAlike 4.0 Int."
    echo
    echo "Written by Sebas Veeke"
}

webot_help() {
    echo "Usage:"
    echo " webot [option]..."
    echo
    echo "Features:"
    echo " -a, --add-webconfig    Start guided creation of new apache configuration"
    echo
    echo "Options:"
    echo " -h, --help             Display this help and exit"
    echo " -v, --version          Display version information and exit"
}

#############################################################################
# FEATURE FUNCTIONS
#############################################################################
# FUNCTIONS
# - create new apache configuration file
# --- insert domain
# ------ with or without www?
# --- with or without security headers?
# --- what profile (1: general, 2: wp etc.)
# ------if true, special security headers for Wordpress?
# --- with or without TLS-certificate?
# ------ if true, then check DNS
# --------- if true, request certificate
# --- if succesful, restart apache

feature_add_webconfig() {
    echo 'webot will guide you through the creation of a new apache'
    echo 'configuration file now. Please answer the following questions:'
    echo
    # ask whether DNS has been configured already and validate input
    # this question is meant to make clear to the user that DNS should really be configured before using webot
    while true
        do
            read -r -p '(1) Did you configure and propagate relevant DNS records? (yes/no): ' DNS_RECORDS
            [ "${DNS_RECORDS}" = 'yes' ] || [ "${DNS_RECORDS}" = 'y' ] || \
            [ "${DNS_RECORDS}" = 'no' ] || [ "${DNS_RECORDS}" = 'n' ] && break
            error_type_yes_or_no
        done

    # show error when user didn't configure DNS
    if [ "${DNS_RECORDS}" = 'no' ] || [ "${DNS_RECORDS}" = 'n' ]; then
        error_dns_required
    # continue when user did configure DNS
    elif [ "${DNS_RECORDS}" = 'yes' ] || [ "${DNS_RECORDS}" = 'y' ]; then
        # ask for the domain name and validate input by checking if the given domain is usable
        # note that webot does not check whether the DNS A and AAAA records are indeed pointing
        # to the device webot is executed from
        while true
            do
                read -r -p '(2) Enter domain name (e.g. domain.tld): ' DOMAIN_NAME
                echo "    Performing DNS lookup for ${DOMAIN_NAME}"
                host ${DOMAIN_NAME} 2>&1 > /dev/null
                [ "$?" -eq '0' ] && break
                    error_invalid_domain
            done
        echo "    Domain ${DOMAIN_NAME} OK"

        # ask for (sub)domain layout and validate input
        echo '(3) Select (sub)domain layout:'
        echo "    1 ${DOMAIN_NAME}"
        echo "    2 www.${DOMAIN_NAME}"
        echo "    3 ${DOMAIN_NAME} and www.${DOMAIN_NAME}"
        while true
            do
                read -r -p '    Layout choice (1-3): ' CHOICE_SUBDOMAIN
                [ "${CHOICE_SUBDOMAIN}" = '1' ] || [ "${CHOICE_SUBDOMAIN}" = '2' ] || \
                [ "${CHOICE_SUBDOMAIN}" = '3' ] && break
                error_type_valid_number
            done

        # ask for webroot
        read -r -p '(4) DocumentRoot (full path): ' WEBROOT_PATH

        # ask for security headers configuration and validate input
        while true
            do
                read -r -p '(5) Add security headers? (yes/no): ' CHOICE_SECURITY_HEADERS
                [ "${CHOICE_SECURITY_HEADERS}" = 'yes' ] || [ "${CHOICE_SECURITY_HEADERS}" = 'y' ] || \
                [ "${CHOICE_SECURITY_HEADERS}" = 'no' ] || [ "${CHOICE_SECURITY_HEADERS}" = 'n' ] && break
                error_type_yes_or_no
            done
        
        # ask whether use wants a tls certificate and validate input
        echo '(6) Add TLS certificate?'
        echo '    1 TLS certificate with RSA key size of 2048 bits (default)'
        echo '    2 TLS certificate with RSA key size of 4096 bits (paranoid)'
        echo '    3 No TLS certificate (not recommended)'
        while true
            do
                read -r -p '    TLS choice (1-3): ' CHOICE_TLS
                [ "${CHOICE_TLS}" = '1' ] || [ "${CHOICE_TLS}" = '2' ] || \
                [ "${CHOICE_TLS}" = '3' ] && break
                error_type_valid_number
            done

        # ask what profile should be used for parameters used during creation of web configuration and validate input
        echo '(7) Select profile:'
        echo '    1 Default profile.'
        echo '    2 Wordpress profile.'
        while true
            do
                read -r -p '    Profile choice (1-2): ' CHOICE_PROFILE
                [ "${CHOICE_PROFILE}" = '1' ] || [ "${CHOICE_PROFILE}" = '2' ] && break
                error_type_valid_number
            done

        # ask whether apache should be restarted after the new web configuration has been created and validate input
        while true
            do
                read -r -p '(8) Restart apache after creation? (yes/no): ' CHOICE_RESTART_APACHE
                [ "${CHOICE_RESTART_APACHE}" = 'yes' ] || [ "${CHOICE_RESTART_APACHE}" = 'y' ] || \
                [ "${CHOICE_RESTART_APACHE}" = 'no' ] || [ "${CHOICE_RESTART_APACHE}" = 'n' ] && break
                error_type_yes_or_no
            done

        # validate user input one last time
        echo
        echo '# FINAL CHECK #'
        echo 'webot will create a apache config file with:'
        echo '############################################################'
        if [ "${CHOICE_SUBDOMAIN}" = '1' ]; then
            echo "    ServerName:         ${DOMAIN_NAME}"
        elif [ "${CHOICE_SUBDOMAIN}" = '2' ]; then
            echo "    ServerName:         www.${DOMAIN_NAME}"
        elif [ "${CHOICE_SUBDOMAIN}" = '3' ]; then
            echo "    ServerName:         ${DOMAIN_NAME}"
            echo "    ServerAlias     www.${DOMAIN_NAME}"
        fi

        echo "    DocumentRoot:       ${WEBROOT_PATH}"

        if [ "${CHOICE_SECURITY_HEADERS}" = 'yes' ]; then
            echo '    HTTP Headers:       X-XSS-Protection: "1; mode=block"'
            echo '                        CSP "default-src https: data: 'unsafe-inline' 'unsafe-eval'"'
            echo '                        X-Frame-Options "SAMEORIGIN"'
            echo '                        X-Content-Type-Options nosniff'
            echo '                        Strict-Transport-Security "max-age=63072000; includeSubdomains; preload"'
            echo '                        Referrer-Policy same-origin'
            echo '                        X-Permitted-Cross-Domain-Policies: none'
        elif [ "${CHOICE_SECURITY_HEADERS}" = 'no' ]; then
            echo "    HTTP Headers:       None"
        fi

        if [ "${CHOICE_TLS}" = '1' ]; then
            echo '    TLS Certificate:    RSA 2048'
        elif [ "${CHOICE_TLS}" = '2' ]; then
            echo '    TLS Certificate:    RSA 4096'
        elif [ "${CHOICE_TLS}" = '3' ]; then
            echo '    TLS Certificate:    None'
        fi

        if [ "${CHOICE_PROFILE}" = '1' ]; then
            echo "    Profile:            Default"
        elif [ "${CHOICE_PROFILE}" = '2' ]; then
            echo "    Profile:            Wordpress"
        fi

        if [ "${CHOICE_RESTART_APACHE}" = 'yes' ]; then
            echo "    Restart Apache:     Yes"
        elif [ "${CHOICE_RESTART_APACHE}" = 'no' ]; then
            echo "    Restart Apache:     No"
        fi
        echo '############################################################'

        # initiate web config creation
        feature_create_webconfig
    fi
}

feature_create_webconfig() {
    echo "DONE!"
}
   
  
            





#############################################################################
# MAIN FUNCTION
#############################################################################

webot_main() {
    # check if os is supported
    requirement_os

    # check argument validity
    requirement_argument_validity

    # call relevant functions based on arguments
    if [ "${ARGUMENT_VERSION}" == '1' ]; then
        webot_version
    elif [ "${ARGUMENT_HELP}" == '1' ]; then
        webot_help
    elif [ "${ARGUMENT_ADD_WEBCONFIG}" == '1' ]; then
        requirement_root
        requirement_os
        requirement_internet
        requirement_apache
        requirement_certbot
        feature_add_webconfig
    elif [ "${ARGUMENT_NONE}" == '1' ]; then
        error_invalid_option
    fi
}

#############################################################################
# CALL MAIN FUNCTION
#############################################################################

webot_main
