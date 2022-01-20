# FreeBSD Apache Sparry
Sparry is a acronym for "SPawn Apache viRtualhosts eveRYwhere" (sorry, couldn't come up with something better ;). Sparry is a easy to use management tool for apache VirtualHost configurations on FreeBSD. With Sparry most people should be able to create apache VirtualHost configurations that are simple and straight forward, but also reasonably secure.

## Features
* **Easy to use**: Sparry is made for (and with!) people that normally would get discouraged if they had to create VirtualHost files with modern minimum security requirements on servers.
* **Automated basic apache configuration** so you don't have to enable the required modules yourself. 
* **Automated TLS certificates** with Let's Encrypt's official certbot client.
* **Automated HTTP Security Headers** based on your use-case (different profiles available).
* **Automated Error logging** based on your use-case (different options available).
* **Generation of example virtual host** configuration that can be manually editted.
* **Made for FreeBSD** and works on basic shell (so no advanced shells like bash or zsh required).

## How to use
Quite easy :). Run `sparry --spawn` and after answering some questions, your VirtualHost configuration file will be spawned. Sparry generates one VirtualHost configuration file (with certificate) for every domain (optionally it includes the `www.` subdomain). Optionally, for more advanced users some configuration parameters can be set in /usr/local/etc/sparry.conf for further finetuning.

## How to install
Copy `sparry` to `/usr/bin/sparry` (owner=root, group=wheel, permissions=555 (read & execute). This looks something like:
```
wget https://raw.githubusercontent.com/nozel-org/freebsd-apache-sparry/master/sparry -O /usr/bin/sparry
chown root:wheel /usr/bin/sparry
chmod 555 /usr/bin/sparry
```

## Examples
### Runthrough
```
root@nozel:/ # sparry --spawn

Sparry will guide you through the creation of a new apache virtual host
configuration file. Please answer the following questions:

(1)  Did you configure and propagate relevant DNS records? [yes/no]: yes
(2)  Enter domain name (e.g. domain.tld): example.tld
     > Performing DNS lookup for example.tld
     > Domain example.tld OK
(3)  Select (sub)domain layout:
     1 example.tld
     2 example.tld and www.example.tld
     [1-2]: 2
     > Performing external IP address lookup
     > External IP address is 11.22.33.44
     > Checking if DNS records have been set correctly
     > Domain example.tld has been configured correctly
(4)  DocumentRoot (full path or empty for /usr/local/www/example.tld):
     :
     default path /usr/local/www will be used
(5)  Add TLS certificate?
     1 TLS certificate with RSA key size of 2048 bits (default)
     2 TLS certificate with RSA key size of 4096 bits (paranoid)
     [1-2]: 2
(5b) Enter Let's Encrypt email address: mail@domain.tld
(6)  Add HTTP security headers?
     1 Strict           [enforce: HTTPS] [disable: ext-resource, inline-css, iframes]
     2 Loose            [enforce: HTTPS] [disable: ext-resource, iframes] [enable: inline-css]
     3 Poor             [enforce: HTTPS] [enable: ext-resource, inline-css, iframes]
     4 Weak             [allow: HTTP]    [enable: ext-resource, inline-css, iframes]
     5 None             [disable: HTTP security headers]
     6 Wordpress        VirtualHost configuration for default Wordpress installation
     7 NextCloud        VirtualHost configuration for default NextCloud installation
     [1-5]: 1
(7)  Add logging?
     1 Error logging
     2 Access logging
     3 Error and access logging
     4 No logging
     [1-4]: 3
(8)  Restart apache after creation? [yes/no]: yes
(9)  Does the following configuration look reasonable?
     ############################################################################
     # ServerName:         example.tld
     # ServerAlias:        www.example.tld
     # DocumentRoot:       /usr/local/www/example.tld
     # TLS certificate:    RSA 4096
     # TLS email address:  mail@domain.tld
     # Selected profile:   strict
     # Security headers:
     #   Strict-Transport-Security: "max-age=31536000; includeSubDomains;"
     #   X-Frame-Options "DENY"
     #   X-XSS-Protection: "1; mode=block"
     #   X-Content-Type-Options "nosniff"
     #   X-Permitted-Cross-Domain-Policies: none
     #   Referrer-Policy same-origin
     #   Content-Security-Policy: default-src https://${DOMAIN_NAME}"
     # Logging:            Error and access logging
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
Stopping apache24.
Waiting for PIDS: 35393.
> Requesting TLS certificate
> Certificate received
> Downloading base VirtualHost template to example.tld.conf
> Setting ownership and permissions on example.tld.conf
> Customizing VirtualHost configuration in example.tld.conf
> Creating document folder /usr/local/www/example.tld
> Setting document folder user and group to www
> Creating test file in /usr/local/www/example.tld/index.html
> Setting test file user and group to www
> Start apache webserver
Syntax OK

     ############################################################################
     # All done! Check example.tld to see your new configuration in action.
     #
     # File locations:
     # VirtualHost configuration:  /usr/local/etc/apache24/Includes/example.tld.conf
     # DocumentRoot directory:     /usr/local/www/example.tld.nl
     # Certificate directory:      /usr/local/etc/letsencrypt/live/example.tld.nl
     ############################################################################
```

### Generated VirtualHost
The example below uses the 'strict' profile.
```
root@webserver:/ # /usr/local/etc/apache24/Includes/example.tld.conf
# apache configuration file generated by sparry
<VirtualHost *:80>
    ServerName example.tld
    ServerAlias www.example.tld
    DocumentRoot /usr/local/www/example.tld

    # Apache directory control access
    <Directory "/usr/local/www/example.tld">
        Require all granted
    </Directory>

    # Logging
    ErrorLog "/var/log/httpd-example.tld-error.log"
    CustomLog "/var/log/httpd-example.tld-access.log" common

    # HTTP Security Headers
    Header always set Strict-Transport-Security: "max-age=31536000; includeSubDomains;"
    Header always set X-Frame-Options "DENY"
    Header always set X-XSS-Protection: "1; mode=block"
    Header always set X-Content-Type-Options "nosniff"
    Header always set X-Permitted-Cross-Domain-Policies: none
    Header always set Referrer-Policy same-origin
    Header always set Content-Security-Policy: "default-src https://example.tld;"

    # Rewrite requests to HTTPS
    RewriteEngine on
    RewriteCond %{SERVER_NAME} =example.tld [OR]
    RewriteCond %{SERVER_NAME} =www.example.tld
    RewriteRule ^ https://%{SERVER_NAME}%{REQUEST_URI} [END,QSA,R=permanent]
</VirtualHost>

<IfModule mod_ssl.c>
<VirtualHost *:443>
    ServerName example.tld
    ServerAlias www.example.tld
    DocumentRoot /usr/local/www/example.tld

    # Apache directory control access
    <Directory "/usr/local/www/example.tld">
        Require all granted
    </Directory>

    # Logging
    ErrorLog "/var/log/httpd-example.tld-error.log"
    CustomLog "/var/log/httpd-example.tld-access.log" common

    # HTTP Security Headers
    Header always set Strict-Transport-Security: "max-age=31536000; includeSubDomains;"
    Header always set X-Frame-Options "DENY"
    Header always set X-XSS-Protection: "1; mode=block"
    Header always set X-Content-Type-Options "nosniff"
    Header always set X-Permitted-Cross-Domain-Policies: none
    Header always set Referrer-Policy same-origin
    Header always set Content-Security-Policy: "default-src https://example.tld;"

    # Let's Encrypt configuration
    SSLCertificateFile /usr/local/etc/letsencrypt/live/example.tld/fullchain.pem
    SSLCertificateKeyFile /usr/local/etc/letsencrypt/live/example.tld/privkey.pem
    Include /usr/local/etc/letsencrypt/options-ssl-apache.conf
</VirtualHost>
</IfModule>
```

## Support
If you have questions, suggestion or find bugs, please let us know via Issues and Discussions.

## Changelog
### 1.3.1-RELEASE (20-01-2022)
- When only the primary domain (without www) is selected, the apache http -> https rule will be set correctly as well.
- Made some preparations for proxy functionality.

### 1.3.0-RELEASE (19-01-2022)
- Big refactor of the previous codebase, with the intend to make it much easier to extend the features and templates in the future.
- Added base templates for VirtualHost configuration files.
- Updated and improved some language, comments and code.
- Put some pieces of code in their own function to make things easier to read.
- Removed the option to not use TLS. From now on, all (non example) generated VirtualHost files need to have TLS enabled. The goal of this software is to provide reasonably secure VirtualHost files, and without TLS this simply isn't possible.
- Removed the option to only use the www subdomain since in that case you can just enter www.domain.tld in sparry.
- Added two more profiles for wordpress and nextcloud since they require fairly specific security headers.
- Switched from STABLE to RELEASE tags.

### 1.2.0-STABLE (14-06-2020)
- Added optional configuration file in /usr/local/etc/sparry.conf for additional finetuning of Sparry.
- Added compatibility with Apache servers that listen on specific IP addresses instead of * [11](https://github.com/nozel-org/freebsd-apache-sparry/issues/11). This can be set in the new configuration file.
- The email address that is required for Let's Encrypt certificates can now be set in the new configuration file [15](https://github.com/nozel-org/freebsd-apache-sparry/issues/15).
- Added certificate location to summery [9](https://github.com/nozel-org/freebsd-apache-sparry/issues/9).
- Fixed bug where http to https rewrite wasn't set correctly when the third security header profile was chosen [13](https://github.com/nozel-org/freebsd-apache-sparry/issues/13).
- Fixed inconsistency in copyright notices [10](https://github.com/nozel-org/freebsd-apache-sparry/issues/10).
- Fixed bug that in certain cases added 'Listen 443' to http.conf wrongly [12](https://github.com/nozel-org/freebsd-apache-sparry/issues/12).

### 1.1.1-STABLE (26-04-2020)
- Fixed bug in CNAME DNS record validation [#7](https://github.com/nozel-org/freebsd-apache-sparry/issues/7).

### 1.1.0-STABLE (26-03-2020)
- Added feature that generates example config that can be easily editted manually.
- Fixed wrong error message bug in requirement_certbot function.
- Renamed 'add_webconfig' internally to 'spawn' to be more in line with the theme.

### 1.0.0-STABLE (21-03-2020)
- First stable release with basic functionality.
- Changed file name to 'sparry' (removed '.sh').
- Can fully spawn VirtualHost configuration files.
- Requests TLS-certificates.
- Sets security headers.
- Configures apache for TLS.

## Future plans
* Automated despawning of virtual hosts, documentroots and certificates.
* Automated hardening of TLS configuration (modern cipher support etc.).
* Automated hardening of Apache configuration.
* Automated configuration of Apache's DoS protection `mod_evasive`.