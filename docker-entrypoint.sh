#!/bin/bash
set -e

# restarting the nginx
service nginx start

# restarting the  php7.2-fpm 
service php7.2-fpm start

exec "$@"
