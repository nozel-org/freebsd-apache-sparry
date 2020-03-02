#!/bin/sh

#############################################################################
# Version 0.1.0-UNSTABLE (01-03-2020)
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
SPARRY_VERSION='0.1.0'

# apache parameters
APACHE_CONFDIR='/usr/local/etc/apache24/Includes'
DEFAULT_DOCUMENTROOT='/usr/local/www'

# populate used variables
DNS_RECORDS='0'
DOMAIN_NAME='0'
CHOICE_SUBDOMAIN='0'
CHOICE_TLS='0'
CHOICE_SECURITY_HEADERS='0'
CHOICE_RESTART_APACHE='0'

# LIMITATIONS
# It's only compatible with default packages/ports and default apache directories and stuff
# - only basic stuff is possible, so for example only 1 domain (with www as subdomain) per config file/cert.

# NOTES
# - makes config per domain
# - doesn't harden base apache or base lets encrypt configuration

# FUTURE/TO-DO
# - maybe add auto harden feature? (apache, TLS/certbot etc.)
# - Add option for self-signed cert?
# - Fix problem with amount of argument validation (it's broken)
# X Add default apache config directory
# X Add error/access logging option

#############################################################################
# ARGUMENTS
#############################################################################

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
    echo 'sparry: invalid argument'
    echo "Use 'sparry --help' for a list of valid arguments."
    exit 1
}

error_wrong_amount_of_arguments() {
    echo 'sparry: wrong amount of arguments'
    echo "Use 'sparry --help' for a list of valid arguments."
    exit 1
}

# requirement errors
error_os_not_supported() {
    echo 'sparry: operating system is not supported.'
    exit 1
}

error_apache_not_installed() {
    echo 'sparry: apache not installed'
    echo "use 'pkg install apache24' or install apache from ports."
    exit 1
}

error_certbot_not_installed() {
    echo 'sparry: certbot not installed'
    echo "use 'pkg install py37-certbot py37-certbot-apache' or install certbot from ports."
}

error_no_root_privileges() {
    echo 'sparry: you need to be root to perform this command'
    echo "use 'sudo sparry', 'sudo -s' or run sparry as root user."
    exit 1
}

error_no_internet_connection() {
    echo 'sparry: access to the internet is required.'
    exit 1
}

# feature errors
error_type_yes_or_no() {
    echo '    error: type yes or no and press enter to continue.'
}

error_type_valid_number() {
    echo '    error: type a valid number and press enter to continue.'
}

error_dns_required() {
    echo '    error: propagated DNS required, please configure DNS first.'
    exit 1
}

error_invalid_domain() {
    echo '    error: invalid domain: add a valid domain. a valid domain:'
    echo '      - consists of domain.tld or subdomain.domain.tld.'
    echo '      - can be reached from this server (nameservers and records).'
}

error_user_validation_failed() {
    echo '    Too bad, but you can always try again. Bye.'
    exit 0
}

#############################################################################
# REQUIREMENT FUNCTIONS
#############################################################################

#requirement_argument_validity() {
    # show error when amount of arguments is not equal to one
    #if [ "$#" -eq 0 ]; then
    #    error_wrong_amount_of_arguments
    #fi
#}

requirement_root() {
    # show error when sparry has no root privileges
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

sparry_version() {
    echo "sparry ${SPARRY_VERSION}"
    echo "Copyright (C) 2019-2020 Nozel."
    echo "License CC Attribution-NonCommercial-ShareAlike 4.0 Int."
    echo
    echo "Written by Sebas Veeke"
}

sparry_help() {
    echo "Usage:"
    echo " sparry [option]..."
    echo
    echo "Features:"
    echo " -a, --add-webconfig    Start guided creation of new apache configuration"
    echo
    echo "Options:"
    echo " -h, --help             Display this help and exit"
    echo " -v, --version          Display version information and exit"
}

feature_add_webconfig() {
    # this function consists of three parts:
    # 1) gather user input          gather information required for creating new web configuration
    # 2) Validate user input        validate user choices by showing a overview
    # 3) effectuate user choices    create the web configuration file with chosen parameters

    ### 1 GATHER USER INPUT
    # the following information will be asked:
    # - what domain name should be used
    # - whether www subdomain should be included
    # - what documentroot path should be used
    # - whether a TLS certificate should be installed
    # - whether HTTP security headers should be installed
    # - what type of logging should be used
    # - whether apache should be restarted afterwards

    echo
    echo 'sparry will guide you through the creation of a new apache'
    echo 'configuration file now. Please answer the following questions:'
    echo
    # ask whether DNS has been configured already and validate input
    # this question is meant to make clear to the user that DNS should really be configured before using sparry
    while true
        do
            read -r -p '(1) Did you configure and propagate relevant DNS records? [yes/no]: ' DNS_RECORDS
            [ "${DNS_RECORDS}" = 'yes' ] || [ "${DNS_RECORDS}" = 'y' ] || \
            [ "${DNS_RECORDS}" = 'no' ] || [ "${DNS_RECORDS}" = 'n' ] && break
            error_type_yes_or_no
        done
    # show error when user didn't configure DNS
    if [ "${DNS_RECORDS}" = 'no' ] || [ "${DNS_RECORDS}" = 'n' ]; then
        error_dns_required
    fi
    # ask for the domain name and validate input by checking if the given domain is usable
    # note that sparry does not check whether the DNS A and AAAA records are indeed pointing
    # to the device sparry is executed from
    while true
        do
            read -r -p '(2) Enter domain name (e.g. domain.tld): ' DOMAIN_NAME
            echo "    Performing DNS lookup for ${DOMAIN_NAME}"
            host "${DOMAIN_NAME}" 2>&1 > /dev/null
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
            read -r -p '    (1-3): ' CHOICE_SUBDOMAIN
            [ "${CHOICE_SUBDOMAIN}" = '1' ] || [ "${CHOICE_SUBDOMAIN}" = '2' ] || \
            [ "${CHOICE_SUBDOMAIN}" = '3' ] && break
            error_type_valid_number
        done
    # ask for DocumentRoot and if empty variable, populate with $DEFAULT_DOCUMENTROOT
    echo '(4) DocumentRoot (full path or empty for FreeBSD default):'
    read -r -p '    : ' DOCUMENTROOT_PATH
    if [ -z "${DOCUMENTROOT_PATH}" ]; then
        DOCUMENTROOT_PATH="${DEFAULT_DOCUMENTROOT}"
        echo "    path ${DOCUMENTROOT_PATH} will be used"
    fi
    # ask whether user wants a tls certificate and validate input
    echo '(5) Add TLS certificate?'
    echo '    1 TLS certificate with RSA key size of 2048 bits (default)'
    echo '    2 TLS certificate with RSA key size of 4096 bits (paranoid)'
    echo '    3 No TLS certificate (not recommended)'
    while true
        do
            read -r -p '    [1-3]: ' CHOICE_TLS
            [ "${CHOICE_TLS}" = '1' ] || [ "${CHOICE_TLS}" = '2' ] || \
            [ "${CHOICE_TLS}" = '3' ] && break
            error_type_valid_number
        done
    # ask for security headers configuration and validate input based on TLS choice
    # because the more strict security headers won't be compatible with http-only traffic
    if [ "${CHOICE_TLS}" = '1' ] || [ "${CHOICE_TLS}" = '2' ]; then
        echo '(6) Add HTTP security headers?'
        echo '    1 Strict    [enforce HTTPS] [disable: ext-resource, inline-css, iframes]'
        echo '    2 Loose     [enforce HTTPS] [disable: ext-resource, iframes] [enable: inline-css]'
        echo '    3 Poor      [enforce HTTPS] [enable: ext-resource, inline-css, iframes]'
        echo '    4 Weak      [allow HTTP]    [enable: ext-resource, inline-css, iframes]'
        echo '    5 None      [disable: HTTP security headers]'
        while true
            do
                read -r -p '    [1-5]: ' CHOICE_SECURITY_HEADERS
                [ "${CHOICE_SECURITY_HEADERS}" = '1' ] || [ "${CHOICE_SECURITY_HEADERS}" = '2' ] || \
                [ "${CHOICE_SECURITY_HEADERS}" = '3' ] || [ "${CHOICE_SECURITY_HEADERS}" = '4' ] || \
                [ "${CHOICE_SECURITY_HEADERS}" = '5' ] && break
                error_type_valid_number
            done
    else
        echo '(6) Add HTTP security headers?'
        echo '    x Strict    [NOT AVAILABLE WITHOUT TLS]'
        echo '    x Loose     [NOT AVAILABLE WITHOUT TLS]'
        echo '    x Poor      [NOT AVAILABLE WITHOUT TLS]'
        echo '    4 Weak      [allow HTTP]    [enable ext-resource, inline-css, iframes]'
        echo '    5 None      [disable HTTP security headers]'
        while true
            do
                read -r -p '    [4-5]: ' CHOICE_SECURITY_HEADERS
                [ "${CHOICE_SECURITY_HEADERS}" = '4' ] || [ "${CHOICE_SECURITY_HEADERS}" = '5' ] && break
                error_type_valid_number
            done
    fi
    # ask what logging configuration should be used
    echo '(7) Add logging?'
    echo '    1 Error logging'
    echo '    2 Access logging'
    echo '    3 Error and access logging'
    echo '    4 No logging'
    while true
        do
            read -r -p '    [1-4]: ' CHOICE_LOGGING
            [ "${CHOICE_SECURITY_HEADERS}" = '1' ] || [ "${CHOICE_SECURITY_HEADERS}" = '2' ] || \
            [ "${CHOICE_SECURITY_HEADERS}" = '3' ] || [ "${CHOICE_SECURITY_HEADERS}" = '4' ] && break
            error_type_valid_number
        done
    # ask whether apache should be restarted after the new web configuration has been created and validate input
    while true
        do
            read -r -p '(8) Restart apache after creation? [yes/no]: ' CHOICE_RESTART_APACHE
            [ "${CHOICE_RESTART_APACHE}" = 'yes' ] || [ "${CHOICE_RESTART_APACHE}" = 'y' ] || \
            [ "${CHOICE_RESTART_APACHE}" = 'no' ] || [ "${CHOICE_RESTART_APACHE}" = 'n' ] && break
            error_type_yes_or_no
        done

    ### 2 VALIDATE USER INPUT
    # show user all given answers and validate user input one last time
    echo '(9) Does the following configuration look reasonable?'
    echo '    ############################################################################'
    if [ "${CHOICE_SUBDOMAIN}" = '1' ]; then
        echo "    # ServerName:         ${DOMAIN_NAME}"
    elif [ "${CHOICE_SUBDOMAIN}" = '2' ]; then
        echo "    # ServerName:         www.${DOMAIN_NAME}"
    elif [ "${CHOICE_SUBDOMAIN}" = '3' ]; then
        echo "    # ServerName:         ${DOMAIN_NAME}"
        echo "    # ServerAlias         www.${DOMAIN_NAME}"
    fi
    echo "    # DocumentRoot:       ${DOCUMENTROOT_PATH}/${DOMAIN_NAME}"
    if [ "${CHOICE_TLS}" = '1' ]; then
        echo '    # TLS Certificate:    RSA 2048'
    elif [ "${CHOICE_TLS}" = '2' ]; then
        echo '    # TLS Certificate:    RSA 4096'
    elif [ "${CHOICE_TLS}" = '3' ]; then
        echo '    # TLS Certificate:    None'
    fi
    if [ "${CHOICE_SECURITY_HEADERS}" = '1' ]; then
        echo '    # Security headers:'
        echo '    #   Strict-Transport-Security: max-age=31536000; includeSubDomains;'
        echo '    #   X-Frame-Options "DENY"'
        echo '    #   X-XSS-Protection: "1; mode=block"'
        echo '    #   X-Content-Type-Options "nosniff"'
        echo '    #   X-Permitted-Cross-Domain-Policies: none'
        echo '    #   Referrer-Policy same-origin'
        echo "    #   Content-Security-Policy: default-src https://${DOMAIN_NAME}"
    elif [ "${CHOICE_SECURITY_HEADERS}" = '2' ]; then
        echo '    # Security headers:'
        echo '    #   Strict-Transport-Security: max-age=31536000; includeSubDomains;'
        echo '    #   X-Frame-Options "DENY"'
        echo '    #   X-XSS-Protection: "1; mode=block"'
        echo '    #   X-Content-Type-Options "nosniff"'
        echo '    #   X-Permitted-Cross-Domain-Policies: none'
        echo '    #   Referrer-Policy same-origin'
        echo "    #   Content-Security-Policy: default-src https://${DOMAIN_NAME}; style-src 'unsafe-inline'"
    elif [ "${CHOICE_SECURITY_HEADERS}" = '3' ]; then
        echo '    # Security headers:'
        echo '    #   Strict-Transport-Security: max-age=31536000; includeSubDomains;'
        echo '    #   X-Frame-Options "SAMEORIGIN"'
        echo '    #   X-XSS-Protection: "1; mode=block"'
        echo '    #   X-Content-Type-Options "nosniff"'
        echo '    #   X-Permitted-Cross-Domain-Policies: none'
        echo '    #   Referrer-Policy same-origin'
        echo "    #   Content-Security-Policy: default-src https:; style-src 'unsafe-inline'"
    elif [ "${CHOICE_SECURITY_HEADERS}" = '4' ]; then
        echo '    # Security headers:'
        echo '    #   X-Frame-Options "SAMEORIGIN"'
        echo '    #   X-XSS-Protection: "1; mode=block"'
        echo '    #   X-Content-Type-Options "nosniff"'
        echo '    #   X-Permitted-Cross-Domain-Policies: none'
        echo '    #   Referrer-Policy same-origin'
    elif [ "${CHOICE_SECURITY_HEADERS}" = '5' ]; then
        echo '    # Security headers:   Disabled'
    fi
    if [ "${CHOICE_LOGGING}" = '1' ]; then
        echo '    # Logging:            Error logging'
    elif [ "${CHOICE_LOGGING}" = '2' ]; then
        echo '    # Logging:            Access logging'
    elif [ "${CHOICE_LOGGING}" = '3' ]; then
        echo '    # Logging:            Error and access logging'
    elif [ "${CHOICE_LOGGING}" = '4' ]; then
        echo '    # Logging:            Disabled'
    fi
    if [ "${CHOICE_RESTART_APACHE}" = 'yes' ]; then
        echo "    # Restart Apache:     Yes"
    elif [ "${CHOICE_RESTART_APACHE}" = 'no' ]; then
        echo "    # Restart Apache:     No"
    fi
    echo '    ############################################################################'
    while true
        do
            read -r -p '    (yes/no): ' USER_VALIDATION
            [ "${USER_VALIDATION}" = 'yes' ] || [ "${USER_VALIDATION}" = 'y' ] || \
            [ "${USER_VALIDATION}" = 'no' ] || [ "${USER_VALIDATION}" = 'n' ] && break
            error_type_yes_or_no
        done

    ### 3 EFFECTUATE USER CHOICES
    # ...
    # stop script if user validation didn't succeed
    if [ "${USER_VALIDATION}" = 'no' ] || [ "${USER_VALIDATION}" = 'n' ]; then
        error_user_validation_failed
    fi
    echo "Creating ${DOMAIN_NAME}.conf in ${APACHE_CONFDIR}"
    touch ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
    echo "Setting ownership and permissions on ${DOMAIN_NAME}.conf"
    chown root:wheel ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
    chmod 644 ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
    echo "Adding VirtualHost for http requests to ${DOMAIN_NAME}.conf"
    echo "# apache configuration file generated by sparry" > ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
    echo '<VirtualHost *:80>' >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
    if [ "${CHOICE_SUBDOMAIN}" = '1' ]; then
        echo "    ServerName ${DOMAIN_NAME}" >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
    elif [ "${CHOICE_SUBDOMAIN}" = '2' ]; then
        echo "    ServerName www.${DOMAIN_NAME}" >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
    elif [ "${CHOICE_SUBDOMAIN}" = '3' ]; then
        echo "    ServerName ${DOMAIN_NAME}" >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
        echo "    ServerAlias www.${DOMAIN_NAME}" >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
    fi
        echo "    DocumentRoot ${DOCUMENTROOT_PATH}" >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
    if [ "${CHOICE_LOGGING}" = '1' ]; then
        echo >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
        echo '    # Logging' >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
        echo '    ErrorLog "/var/log/httpd-'"${DOMAIN_NAME}-error.log"'"' >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
    elif [ "${CHOICE_LOGGING}" = '2' ]; then
        echo >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
        echo '    # Logging' >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
        echo '    CustomLog "/var/log/httpd-'"${DOMAIN_NAME}-access.log"'" common' >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
    elif [ "${CHOICE_LOGGING}" = '3' ]; then
        echo >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
        echo '    # Logging' >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
        echo '    ErrorLog "/var/log/httpd-'"${DOMAIN_NAME}-error.log"'"' >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
        echo '    CustomLog "/var/log/httpd-'"${DOMAIN_NAME}-access.log"'" common' >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
    fi
    if [ "${CHOICE_SECURITY_HEADERS}" = '1' ]; then
        echo >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
        echo '    # HTTP Security Headers' >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
        echo '    Header always set HTTP Security Headers' >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
        echo '    Header always set Strict-Transport-Security: max-age=31536000; includeSubDomains;' >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
        echo '    Header always set X-Frame-Options "DENY"' >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
        echo '    Header always set X-XSS-Protection: "1; mode=block"' >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
        echo '    Header always set X-Content-Type-Options "nosniff"' >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
        echo '    Header always set X-Permitted-Cross-Domain-Policies: none' >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
        echo '    Header always set Referrer-Policy same-origin' >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
        echo "    Header always set Content-Security-Policy: default-src https://${DOMAIN_NAME}" >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
        echo >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
        echo '    # Rewrite requests to HTTPS' >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
        echo '    RewriteEngine on' >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
        echo "    RewriteCond %{SERVER_NAME} =${DOMAIN_NAME} [OR]" >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
        echo "    RewriteCond %{SERVER_NAME} =www.${DOMAIN_NAME}" >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
        echo '    RewriteRule ^ https://%{SERVER_NAME}%{REQUEST_URI} [END,QSA,R=permanent]' >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
    elif [ "${CHOICE_SECURITY_HEADERS}" = '2' ]; then
        echo >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
        echo '    # HTTP Security Headers' >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
        echo '    Header always set HTTP Security Headers' >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
        echo '    Header always set Strict-Transport-Security: max-age=31536000; includeSubDomains;' >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
        echo '    Header always set X-Frame-Options "DENY"' >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
        echo '    Header always set X-XSS-Protection: "1; mode=block"' >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
        echo '    Header always set X-Content-Type-Options "nosniff"' >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
        echo '    Header always set X-Permitted-Cross-Domain-Policies: none' >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
        echo '    Header always set Referrer-Policy same-origin' >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
        echo "    Header always set Content-Security-Policy: default-src https://${DOMAIN_NAME}; style-src 'unsafe-inline'" >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
        echo >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
        echo '    # Rewrite requests to HTTPS' >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
        echo '    RewriteEngine on' >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
        echo "    RewriteCond %{SERVER_NAME} =${DOMAIN_NAME} [OR]" >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
        echo "    RewriteCond %{SERVER_NAME} =www.${DOMAIN_NAME}" >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
        echo '    RewriteRule ^ https://%{SERVER_NAME}%{REQUEST_URI} [END,QSA,R=permanent]' >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
    elif [ "${CHOICE_SECURITY_HEADERS}" = '3' ]; then
        echo >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
        echo '    # HTTP Security Headers' >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
        echo '    Header always set Strict-Transport-Security: max-age=31536000; includeSubDomains;' >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
        echo '    Header always set X-Frame-Options "SAMEORIGIN"' >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
        echo '    Header always set X-XSS-Protection: "1; mode=block"' >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
        echo '    Header always set X-Content-Type-Options "nosniff"' >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
        echo '    Header always set X-Permitted-Cross-Domain-Policies: none' >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
        echo '    Header always set Referrer-Policy same-origin' >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
        echo "    Header always set Content-Security-Policy: default-src https:; style-src 'unsafe-inline'" >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
        echo >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
        echo '    # Rewrite requests to HTTPS' >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
        echo '    RewriteEngine on' >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
        echo "    RewriteCond %{SERVER_NAME} =${DOMAIN_NAME} [OR]" >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
        echo "    RewriteCond %{SERVER_NAME} =www.${DOMAIN_NAME}" >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
        echo '    RewriteRule ^ https://%{SERVER_NAME}%{REQUEST_URI} [END,QSA,R=permanent]' >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
    elif [ "${CHOICE_SECURITY_HEADERS}" = '4' ]; then
        echo >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
        echo '    # HTTP Security Headers' >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
        echo '    Header always set X-Frame-Options "SAMEORIGIN"' >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
        echo '    Header always set X-XSS-Protection: "1; mode=block"' >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
        echo '    Header always set X-Content-Type-Options "nosniff"' >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
        echo '    Header always set X-Permitted-Cross-Domain-Policies: none' >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
        echo '    Header always set Referrer-Policy same-origin' >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
    fi
    echo '</VirtualHost>' >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
    if [ "${CHOICE_TLS}" = '1' ] || [ "${CHOICE_TLS}" = '2' ]; then
        echo "Adding VirtualHost for https requests to ${DOMAIN_NAME}.conf"
        echo >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
        echo '<IfModule mod_ssl.c>' >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
        echo '<VirtualHost *:443>' >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
        if [ "${CHOICE_SUBDOMAIN}" = '1' ]; then
            echo "    ServerName ${DOMAIN_NAME}" >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
        elif [ "${CHOICE_SUBDOMAIN}" = '2' ]; then
            echo "    ServerName www.${DOMAIN_NAME}" >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
        elif [ "${CHOICE_SUBDOMAIN}" = '3' ]; then
            echo "    ServerName ${DOMAIN_NAME}" >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
            echo "    ServerAlias www.${DOMAIN_NAME}" >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
        fi
            echo "    DocumentRoot ${DOCUMENTROOT_PATH}" >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
        if [ "${CHOICE_LOGGING}" = '1' ]; then
            echo >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
            echo '    # Logging' >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
            echo '    ErrorLog "/var/log/httpd-'"${DOMAIN_NAME}-error.log"'"' >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
        elif [ "${CHOICE_LOGGING}" = '2' ]; then
            echo >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
            echo '    # Logging' >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
            echo '    CustomLog "/var/log/httpd-'"${DOMAIN_NAME}-access.log"'" common' >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
        elif [ "${CHOICE_LOGGING}" = '3' ]; then
            echo >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
            echo '    # Logging' >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
            echo '    ErrorLog "/var/log/httpd-'"${DOMAIN_NAME}-error.log"'"' >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
            echo '    CustomLog "/var/log/httpd-'"${DOMAIN_NAME}-access.log"'" common' >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
        fi
        if [ "${CHOICE_SECURITY_HEADERS}" = '1' ]; then
            echo >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
            echo '    # HTTP Security Headers' >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
            echo '    Header always set HTTP Security Headers' >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
            echo '    Header always set Strict-Transport-Security: max-age=31536000; includeSubDomains;' >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
            echo '    Header always set X-Frame-Options "DENY"' >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
            echo '    Header always set X-XSS-Protection: "1; mode=block"' >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
            echo '    Header always set X-Content-Type-Options "nosniff"' >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
            echo '    Header always set X-Permitted-Cross-Domain-Policies: none' >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
            echo '    Header always set Referrer-Policy same-origin' >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
            echo "    Header always set Content-Security-Policy: default-src https://${DOMAIN_NAME}" >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
        elif [ "${CHOICE_SECURITY_HEADERS}" = '2' ]; then
            echo >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
            echo '    # HTTP Security Headers' >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
            echo '    Header always set HTTP Security Headers' >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
            echo '    Header always set Strict-Transport-Security: max-age=31536000; includeSubDomains;' >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
            echo '    Header always set X-Frame-Options "DENY"' >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
            echo '    Header always set X-XSS-Protection: "1; mode=block"' >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
            echo '    Header always set X-Content-Type-Options "nosniff"' >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
            echo '    Header always set X-Permitted-Cross-Domain-Policies: none' >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
            echo '    Header always set Referrer-Policy same-origin' >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
            echo "    Header always set Content-Security-Policy: default-src https://${DOMAIN_NAME}; style-src 'unsafe-inline'" >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
        elif [ "${CHOICE_SECURITY_HEADERS}" = '3' ]; then
            echo >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
            echo '    # HTTP Security Headers' >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
            echo '    Header always set Strict-Transport-Security: max-age=31536000; includeSubDomains;' >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
            echo '    Header always set X-Frame-Options "SAMEORIGIN"' >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
            echo '    Header always set X-XSS-Protection: "1; mode=block"' >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
            echo '    Header always set X-Content-Type-Options "nosniff"' >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
            echo '    Header always set X-Permitted-Cross-Domain-Policies: none' >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
            echo '    Header always set Referrer-Policy same-origin' >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
            echo "    Header always set Content-Security-Policy: default-src https:; style-src 'unsafe-inline'" >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
        elif [ "${CHOICE_SECURITY_HEADERS}" = '4' ]; then
            echo >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
            echo '    # HTTP Security Headers' >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
            echo '    Header always set X-Frame-Options "SAMEORIGIN"' >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
            echo '    Header always set X-XSS-Protection: "1; mode=block"' >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
            echo '    Header always set X-Content-Type-Options "nosniff"' >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
            echo '    Header always set X-Permitted-Cross-Domain-Policies: none' >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
            echo '    Header always set Referrer-Policy same-origin' >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
        fi
        echo '</VirtualHost>' >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
        echo '</IfModule>' >> ${APACHE_CONFDIR}/${DOMAIN_NAME}.conf
    fi
}

#############################################################################
# MAIN FUNCTION
#############################################################################

sparry_main() {
    # check if os is supported
    requirement_os

    # check argument validity
    #requirement_argument_validity

    # call relevant functions based on arguments
    if [ "${ARGUMENT_VERSION}" = '1' ]; then
        sparry_version
    elif [ "${ARGUMENT_HELP}" = '1' ]; then
        sparry_help
    elif [ "${ARGUMENT_ADD_WEBCONFIG}" = '1' ]; then
        requirement_root
        requirement_os
        requirement_internet
        requirement_apache
        requirement_certbot
        feature_add_webconfig
    elif [ "${ARGUMENT_NONE}" = '1' ]; then
        error_invalid_option
    fi
}

#############################################################################
# CALL MAIN FUNCTION
#############################################################################

sparry_main
