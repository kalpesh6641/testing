From ubuntu:18.04

# Updating the ubuntu time zone
ENV TZ=America/Chicago
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Configure Package Management
COPY scripts/sources.list /etc/apt/sources.list
RUN apt-get update
RUN apt-get install -y curl

# Add usbank certs
RUN curl -o /usr/share/ca-certificates/usb_ca_chain.crt https://mra-repo1.us.bank-dns.com/artifactory/centos7/usb_ca_chain.crt --insecure
RUN echo "usb_ca_chain.crt" >> /etc/ca-certificates.conf && update-ca-certificates

# Updating the packages in base image
RUN apt update -y && apt upgrade -y

# Install essential tools
RUN apt install -y acl curl wget git software-properties-common unzip zip

# Install PHP
RUN apt install -y php7.2 php7.2-fpm php7.2-cli php7.2-common php7.2-apcu \
                    php7.2-yaml php7.2-gd php7.2-mbstring php-pear \
                    php7.2-curl php7.2-dev php7.2-opcache php7.2-xml \
                    php7.2-zip php7.2-mysql php7.2-sqlite

# Install Nginx
RUN apt remove apache2* \
    && apt autoremove \
    && apt install -y nginx

# Updating the packages in base image
RUN apt update -y && apt upgrade -y

COPY scripts/docker-entrypoint.sh /usr/local/bin
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Adding grav user to the image
RUN useradd -m -d /home/grav grav

# Update the php.ini files with respective configuration
RUN sed -i "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/" /etc/php/7.2/cli/php.ini
RUN sed -i "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/" /etc/php/7.2/fpm/php.ini
RUN sed -i "s/;date.timezone =/date.timezone=UTC/" /etc/php/7.2/fpm/php.ini

# Remove unwated files
RUN rm -f /etc/nginx/sites-enabled/* \
  && rm -f /etc/nginx/sites-available/*

# Configure Nginx Connection pool
RUN cd /etc/php/7.2/fpm/pool.d/ && mv www.conf www.conf.bak

# Grav Configuration
COPY scripts/grav.conf /etc/php/7.2/fpm/pool.d

# Install Composer
RUN curl -sS https://getcomposer.org/installer | php
RUN mv composer.phar /usr/local/bin/composer
RUN chmod 775 -R /usr/local/bin && composer --version

# Set up web root folders and create temp index.php
RUN su grav -c "mkdir -p ~/www/html && echo \"<?php phpinfo();\" >> ~/www/html/index.php"

# Change group ownership
RUN cd /home/grav/www && chown -R grav:www-data html/

# Add /etc/nginx/sites-available/
COPY scripts/grav /etc/nginx/sites-available/

RUN ln -s /etc/nginx/sites-available/grav /etc/nginx/sites-enabled/

# Install grav
RUN su grav -c "cd /home/grav/www/html \
    && wget https://github.com/getgrav/grav/releases/download/1.4.5/grav-admin-v1.4.5.zip \
    && unzip grav-admin-v1.4.5.zip && mv grav-admin grav"

# Exposing the ports
EXPOSE 80
EXPOSE 443

# Fixing the permissions
RUN su root -c "cd /home/grav/www/html/grav \
      && find . -type f | xargs chmod 664 \
      && find ./bin -type f | xargs chmod 775 \
      && find . -type d | xargs chmod 775 \
      && find . -type d | xargs chmod +s"

# setting the working directory to /home/grav/www/html/grav
WORKDIR /home/grav/www/html/grav

# Updating the permission to be the correct owner
RUN chown -R grav:grav /home/grav/www/html/grav

# Adding entry point to start the nginx and php7.2-fpm on boot
ENTRYPOINT ["docker-entrypoint.sh"]

# Runs the command as bash
CMD ["/bin/bash"]
