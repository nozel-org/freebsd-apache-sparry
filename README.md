# FreeBSD Apache Sparry
Sparry is a acronym for "SPawn Apache viRtualhosts eveRYwhere" (sorry, couldn't come up with something better ;). Sparry is a easy to use management tool for apache VirtualHost configurations on FreeBSD. With Sparry most people should be able to create apache VirtualHost configurations that are simple and straight forward, but also reasonably secure.

## Current features
* **Easy to use**: Sparry is made for (and with!) people that normally would get discouraged if they had to create VirtualHost files with modern minimum security requirements on servers.
* **Automated basic apache configuration** so you don't have to enable modules yourself. 
* **Automated TLS certificates** with Let's Encrypt's official certbot client.
* **Automated HTTP Security Headers** based on your use-case (different profiles available).
* **Automated Error logging** based on your use-case (different options available).
* **Generation of example virtual host** configuration that can be manually editted.
* **Made for FreeBSD** and works on basic shell (so no advanced shells like bash or zsh required).

## Future plans
* Automated despawning of virtual hosts, documentroots and certificates.
* Automated hardening of TLS configuration (modern cipher support etc.).

## How does it work
Sparry asks some questions and will generate a VirtualHost configuration file and configure apache based on the answers given. Nothing too special. There is one VirtualHost configuration file for every domain.

## Limitations
Sparry is really meant for basic tasks and is not suited for more advanced stuff like other subdomains than `www`, multiple domains in one file or the more complex Apache stuff.

## Examples
### Runthrough
```
root@nozel:~ # sparry --spawn

Sparry will guide you through the creation of a new apache virtual host
configuration file now. Please answer the following questions:

(1)  Did you configure and propagate relevant DNS records? [yes/no]: yes
(2)  Enter domain name (e.g. domain.tld): nozel.org
     > Performing DNS lookup for nozel.org
     > Domain nozel.org OK
(3)  Select (sub)domain layout:
     1 nozel.org
     2 www.nozel.org
     3 nozel.org and nozel.org
     [1-3]: 3
     > Performing external IP address lookup
     > External IP address is 100.100.100.100
     > Checking if DNS records have been set correctly
     > Domain nozel.org has been configured correctly
     > Domain www.nozel.org has been configured correctly
(4)  DocumentRoot (full path or empty for FreeBSD default):
     :
     default path /usr/local/www will be used
(5)  Add TLS certificate?
     1 TLS certificate with RSA key size of 2048 bits (default)
     2 TLS certificate with RSA key size of 4096 bits (paranoid)
     3 No TLS certificate (not recommended)
     [1-3]: 2
(5b) Enter Let's Encrypt email address: certs@nozel.org
(6)  Add HTTP security headers?
     1 Strict    [enforce: HTTPS] [disable: ext-resource, inline-css, iframes]
     2 Loose     [enforce: HTTPS] [disable: ext-resource, iframes] [enable: inline-css]
     3 Poor      [enforce: HTTPS] [enable: ext-resource, inline-css, iframes]
     4 Weak      [allow: HTTP]    [enable: ext-resource, inline-css, iframes]
     5 None      [disable: HTTP security headers]
     [1-5]: 1
(7)  Add logging?
     1 Error logging
     2 Access logging
     3 Error and access logging
     4 No logging
     [1-4]: 1
(8)  Restart apache after creation? [yes/no]: yes
(9)  Does the following configuration look reasonable?
     ############################################################################
     # ServerName:         nozel.org
     # ServerAlias         www.nozel.org
     # DocumentRoot:       /usr/local/www/nozel.org
     # TLS certificate:    RSA 4096
     # TLS email address:  certs@nozel.org
     # Security headers:
     #   Strict-Transport-Security: "max-age=31536000; includeSubDomains;"
     #   X-Frame-Options "DENY"
     #   X-XSS-Protection: "1; mode=block"
     #   X-Content-Type-Options "nosniff"
     #   X-Permitted-Cross-Domain-Policies: none
     #   Referrer-Policy same-origin
     #   Content-Security-Policy: default-src https://nozel.org
     # Logging:            Error logging
     # Restart Apache:     Yes
     ############################################################################
     (yes/no): yes

Effectuating user choices

> Checking httpd.conf for required apache modules
> ssl_module is already enabled
> rewrite_module is already enabled
> Checking if apache listens on port 443
> Apache is already listening on port 443
> Checking if port 80 is being currently used
> Port 80 is being used, trying to find service
> Apache found on port 80, stopping service apache
> Requesting TLS certificate
> Certificate received
> Creating nozel.org.conf in /usr/local/etc/apache24/Includes
> Setting ownership and permissions on nozel.org.conf
> Adding VirtualHost for http requests to nozel.org.conf
> Adding VirtualHost for https requests to nozel.org.conf
> Directory /usr/local/www/nozel.org already exists, skipping creation
> File /usr/local/www/nozel.org/index.html already exists, skipping creation
> Start apache webserver

     ############################################################################
     # All done! Check nozel.org to see your new configuration in action.
     #
     # File locations:
     # Virtual host configuration: /usr/local/etc/apache24/Includes/nozel.org.conf
     # DocumentRoot directory:     /usr/local/www/nozel.org
     ############################################################################

```

### Generated VirtualHost
The example below uses the 'strict' HTTP Security Headers profile.
```
# apache configuration file generated by sparry
<VirtualHost *:80>
    ServerName nozel.org
    ServerAlias www.nozel.org
    DocumentRoot /usr/local/www/nozel.org

    # Apache directory control access
    <Directory "/usr/local/www/nozel.org">
        Require all granted
    </Directory>

    # Logging
    ErrorLog "/var/log/httpd-nozel.org-error.log"

    # HTTP Security Headers
    Header always set Strict-Transport-Security: "max-age=31536000; includeSubDomains;"
    Header always set X-Frame-Options "DENY"
    Header always set X-XSS-Protection: "1; mode=block"
    Header always set X-Content-Type-Options "nosniff"
    Header always set X-Permitted-Cross-Domain-Policies: none
    Header always set Referrer-Policy same-origin
    Header always set Content-Security-Policy: "default-src https://nozel.org;"

    # Rewrite requests to HTTPS
    RewriteEngine on
    RewriteCond %{SERVER_NAME} =nozel.org [OR]
    RewriteCond %{SERVER_NAME} =www.nozel.org
    RewriteRule ^ https://%{SERVER_NAME}%{REQUEST_URI} [END,QSA,R=permanent]
</VirtualHost>

<IfModule mod_ssl.c>
<VirtualHost *:443>
    ServerName nozel.org
    ServerAlias www.nozel.org
    DocumentRoot /usr/local/www/nozel.org

    # Apache directory control access
    <Directory "/usr/local/www/nozel.org">
        Require all granted
    </Directory>

    # Logging
    ErrorLog "/var/log/httpd-nozel.org-error.log"

    # HTTP Security Headers
    Header always set Strict-Transport-Security: "max-age=31536000; includeSubDomains;"
    Header always set X-Frame-Options "DENY"
    Header always set X-XSS-Protection: "1; mode=block"
    Header always set X-Content-Type-Options "nosniff"
    Header always set X-Permitted-Cross-Domain-Policies: none
    Header always set Referrer-Policy same-origin
    Header always set Content-Security-Policy: "default-src https://nozel.org;"

    # Let's Encrypt configuration
    SSLCertificateFile /usr/local/etc/letsencrypt/live/nozel.org/fullchain.pem
    SSLCertificateKeyFile /usr/local/etc/letsencrypt/live/nozel.org/privkey.pem
    Include /usr/local/etc/letsencrypt/options-ssl-apache.conf
</VirtualHost>
</IfModule>
```

## Support
If you have questions/suggestions about Sparry or find bugs, please let us know via the issue tracker.

## Changelog
### 1.1.0-STABLE
- Added feature that generates example config that can be easily editted manually.
- Fixed wrong error message bug in requirement_certbot function.
- Renamed 'add_webconfig' internally to 'spawn' to be more in line with the theme.

### 1.0.0-STABLE
- First stable release with basic functionality.
- Changed file name to 'sparry' (removed '.sh').
- Can fully spawn VirtualHost configuration files.
- Requests TLS-certificates.
- Sets security headers.
- Configures apache for TLS.
