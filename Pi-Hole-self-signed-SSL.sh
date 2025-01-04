#!/bin/bash

# Check if the script is run as root
if [ "$EUID" -ne 0 ]; then
    echo -e "\e[31mThis script must be run as root or with sudo! \e[0m"
    exit 1
fi

echo -e "\e[32m✓ Installing lighttpd-mod-openssl if not already installed...\e[0m"
apt update
apt install -y lighttpd-mod-openssl

echo -e "\e[32m✓ Switching to the /etc/lighttpd directory... \e[0m"
cd /etc/lighttpd/ || { echo -e "\e[31m Failed to navigate to /etc/lighttpd \e[0m"; exit 1; }

echo -e "\e[32m Creating SSL directory... \e[0m"
mkdir -p ssl
cd ssl || { echo -e "\e[31m Failed to navigate to /etc/lighttpd/ssl \e[0m"; exit 1; }

echo -e "\e[32m✓ Generating RSA 2048-bit private key and self-signed certificate without prompts... \e[0m"
openssl req -newkey rsa:2048 -nodes -keyout pihole.key -x509 -days 3650 -out pihole.crt -subj "/C=US/ST=California/L=YourCity/O=YourOrganization/OU=YourOrganizationalUnit/CN=YourCommonName/emailAddress=YourEmail@example.com"

echo -e "\e[32m✓ Combining private key and certificate into a single PEM file...\e[0m"
cat pihole.key pihole.crt > combined.pem

echo -e "\e[32m✓ Setting ownership and permissions for the PEM file...\e[0m"
chown www-data:www-data combined.pem
chmod 600 combined.pem

echo -e "\e[32m✓ Cleaning up temporary key and certificate files...\e[0m"
rm -f pihole.key pihole.crt

echo -e "\e[32m✓ Navigating to the /etc/lighttpd/conf-enabled directory...\e[0m"
cd /etc/lighttpd/conf-enabled/ || { echo -e "\e[31m Failed to navigate to /etc/lighttpd/conf-enabled \e[0m"; exit 1; }

echo -e "\e[32m✓ Creating the 20-pihole-external.conf configuration file...\e[0m"
cat <<'EOF' > 20-pihole-external.conf
# Loading openssl
server.modules += ( "mod_openssl" )

setenv.add-environment = ("fqdn" => "true")
$SERVER["socket"] == ":443" {
	ssl.engine  = "enable"
	ssl.pemfile = "/etc/lighttpd/ssl/combined.pem"
	ssl.openssl.ssl-conf-cmd = ("MinProtocol" => "TLSv1.2", "Options" => "-ServerPreference")
}

# Redirect HTTP to HTTPS
$HTTP["scheme"] == "http" {
    $HTTP["host"] =~ ".*" {
        url.redirect = (".*" => "https://%0$0")
    }
}
EOF

echo -e "\e[32m✓ Restarting lighttpd service to apply changes...\e[0m"
systemctl restart lighttpd.service

echo -e "\e[32m✓ SSL setup and configuration completed successfully.\e[0m"
