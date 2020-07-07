#!/bin/bash

sleep 5

sed -i -e "s/\(agent.nodeName = \).*/\1$HOSTNAME/" /etc/php/7.4/fpm/conf.d/appdynamics_agent.ini


sleep 5

/etc/init.d/php7.4-fpm restart

sleep 5

/usr/bin/supervisord
