FROM ubuntu:18.04
MAINTAINER Sayam Sriphua <sayam@buu.ac.th>

ARG DEBIAN_FRONTEND=noninteractive
ENV DEBIAN_FRONTEND noninteractive
RUN export DEBIAN_FRONTEND=noninteractive

RUN apt-get update -y && \
    apt-get -y dist-upgrade && \
    apt-get install -y gcc g++ make autoconf libc-dev pkg-config git \
    wget vim curl mc gnupg2 ca-certificates lsb-release locales \
    software-properties-common supervisor

RUN DEBIAN_FRONTEND=noninteractive apt-get install -y tzdata && \
    ln -fs /usr/share/zoneinfo/Asia/Bangkok /etc/localtime && \
    dpkg-reconfigure --frontend noninteractive tzdata && \
    localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8

RUN bash -c \
    'echo "deb http://nginx.org/packages/ubuntu `lsb_release -cs` nginx" > /etc/apt/sources.list.d/nginx.list' && \
    curl -fsSL https://nginx.org/keys/nginx_signing.key | apt-key add - && \
    apt-key fingerprint ABF5BD827BD9BF62 && \
    bash -c \
    'echo "" | add-apt-repository universe; \
     echo "" | add-apt-repository ppa:ondrej/php; \
     echo "" | add-apt-repository ppa:certbot/certbot'

RUN apt-get update -y && \
    apt-get install -y nginx && \
    mkdir -p /run/php && \
    mkdir -p /etc/nginx/certs && \
    mkdir -p /usr/share/nginx/moodle && \
    mkdir -p /usr/share/nginx/moodledata && \
    chown -R nginx:nginx /run/php

RUN apt-get update -y && \
    apt-get install -y php7.4-cli php7.4-common php7.4-dev php7.4-json php7.4-snmp \
    php7.4-soap php7.4-mbstring php7.4-opcache php7.4-gmp php7.4-curl php7.4-xsl \
    php7.4-tidy php7.4-ldap php7.4-intl php7.4-xmlrpc php7.4-xml php7.4-gd php7.4-readline \
    php7.4-zip php7.4-bz2 php7.4-mysql php7.4-sqlite3 php7.4-pspell php7.4-fpm php-imagick && \
    apt-get install -y certbot python-certbot-nginx

RUN sed -i \
    -e "s/worker_processes  1/worker_processes  auto/g" \
    -e "s/\#gzip  on\;/\#gzip  on\;\n\
    client_max_body_size 544m\;\n\
    server_names_hash_bucket_size 64\;/g" \
    /etc/nginx/nginx.conf && \
    sed -i \
    -e "s/user = www-data/user = nginx/g" \
    -e "s/group = www-data/group = nginx/g" \
    -e "s/listen.owner = www-data/listen.owner = nginx/g" \
    -e "s/listen.group = www-data/listen.group = nginx/g" \
    -e "s/;catch_workers_output\s*=\s*yes/catch_workers_output = yes/g" \
    -e "s/pm.max_children = 5/pm.max_children = 50/g" \
    -e "s/pm.start_servers = 2/pm.start_servers = 6/g" \
    -e "s/pm.min_spare_servers = 1/pm.min_spare_servers = 2/g" \
    -e "s/pm.max_spare_servers = 3/pm.max_spare_servers = 10/g" \
    -e "s/;pm.max_requests = 500/pm.max_requests = 500/g" \
    -e "s/;listen.mode = 0660/listen.mode = 0666/g" \
    -e "s/^;clear_env = no$/clear_env = no/" \
    /etc/php/7.4/fpm/pool.d/www.conf && \
    sed -i \
    -e "s/;date.timezone =/date.timezone = Asia\/Bangkok/g" \
    -e "s/;session.save_path = \"\/var\/lib\/php\/sessions\"/session.save_path = \"\/var\/lib\/php\/sessions\"/g" \
    -e "s/upload_max_filesize = 2M/upload_max_filesize = 5120M/g" \
    -e "s/max_execution_time = 30/max_execution_time = 600/g" \
    -e "s/max_input_time = 60/max_input_time = 660/g" \
    -e "s/post_max_size = 8M/post_max_size = 5760M/g" \
    -e "s/display_errors = Off/display_errors = On\n;display_errors = Off/g" \
    -e "s/error_reporting = E_ALL/error_reporting = E_ALL\n;error_reporting = E_ALL/g" \
    /etc/php/7.4/fpm/php.ini && \
    sed -i \
    -e  '1h;2,$H;$!d;g' \
    -re 's/(\/\s\{\n(\s+))root(\s+)/\1try_files \$uri \$uri\/ \/index.php;\n\2root /g' \
    /etc/nginx/conf.d/default.conf && \
    sed -i \
    -e "s/localhost/exam.stou.ac.th/g" \
    -e "s/index  index\.html index\.htm/index  index.php index.html index\.htm/g" \
    -e "s/ pass the PHP scripts.*$/ pass the PHP scripts to FastCGI server listening on 127.0.0.1:9000\n\
    location ~* \\\.php\$ {\n\
        \#try_files \$uri \$uri\/ =404;\n\
        try_files \$uri \$uri\/ \/index.php;\n\
        root \/usr\/share\/nginx\/html;\n\
        index  index.php index.html index.htm;\n\
	fastcgi_split_path_info \^\(\.\+\?\\\.php\)\(\/\.\*\)\$;\n\
        fastcgi_pass   unix\:\/run\/php\/php7.4\-fpm.sock;\n\
        fastcgi_index  index.php;\n\
        fastcgi_param  SCRIPT_FILENAME   \$document_root\$fastcgi_script_name;\n\
        fastcgi_param  QUERY_STRING      \$query_string;\n\
        fastcgi_param  PATH_INFO         \$fastcgi_path_info;\n\
        include        fastcgi_params;\n    }/g" \
    /etc/nginx/conf.d/default.conf && \
    cp -p /etc/nginx/conf.d/default.conf /etc/nginx/conf.d/default.conf-ssl && \
    cp -pf /etc/php/7.4/fpm/php.ini /etc/php/7.4/cli/php.ini


RUN sed -i \
    -e "s/listen       80;/\#\n\
    \# SSL configuration\n\
    \#\n\
    listen 443 ssl;\n\
    add_header Strict-Transport-Security max-age=31536000;\n\
    ssl_protocols TLSv1 TLSv1.1 TLSv1.2;\n\
    ssl_ciphers ECDH+AESGCM:DH+AESGCM:ECDH+AES256:DH+AES256:ECDH+AES128:DH+AES:ECDH+3DES:DH+3DES:RSA+AESGCM:RSA+AES:RSA+3DES:!aNULL:!MD5:!DSS;\n\
    ssl_buffer_size 8k;\n\
    ssl_prefer_server_ciphers on;\n\
    ssl_session_cache shared:SSL:30m;\n\
    ssl_session_timeout 30m;\n\
    ssl_certificate \/etc\/nginx\/certs\/cert.pem;\n\
    ssl_certificate_key \/etc\/nginx\/certs\/privkey.pem;\n\n\
    \# Specifies a file with DH parameters for EDH ciphers\n\
    \# Run \"openssl dhparam -out \/etc\/nginx\/certs\/dhparam.pem 2048\" in\n\
    \# terminal to generate it\n\
    ssl_dhparam \/etc\/nginx\/certs\/dhparam.pem;\n\n\
    ssl_stapling on;\n\
    resolver 8.8.8.8;\n\
    ssl_stapling_verify on;\n\
    ssl_trusted_certificate \/etc\/nginx\/certs\/fullchain.pem;\n\n\
    \#\n\
    \# Basic configuration\n\
    \#\
    /g" \
    /etc/nginx/conf.d/default.conf-ssl && \
    sed -i \
    -e "s/root \/usr\/share\/nginx\/html/root \/usr\/share\/nginx\/moodle/g" \
    /etc/nginx/conf.d/default.conf && \
    sed -i \
    -e "s/root \/usr\/share\/nginx\/html/root \/usr\/share\/nginx\/moodle/g" \
    /etc/nginx/conf.d/default.conf-ssl && \
    sed -i \
    -e "s/\$TEMP)/\$TEMP)\nnodaemon=true/g" \
    /etc/supervisor/supervisord.conf

RUN apt-get -y autoremove && \
    apt-get clean && \
    apt-get autoclean && \
    rm -rf /tmp/pear && \
    rm -f /etc/php/7.4/fpm/conf.d/20-xdebug.ini

# Configure Services and Port
EXPOSE 80 443
STOPSIGNAL SIGTERM

#AppD
ADD appdynamics-php-agent-linux_x64 /opt/appdynamics/php-agent
RUN tar xvjf /opt/appdynamics/php-agent/appdynamics-php-agent-linux_x64.tar.bz2
RUN chmod -R 777 /opt/appdynamics
RUN /opt/appdynamics/php-agent/runme.sh
RUN cp /etc/php/7.4/cli/conf.d/appdynamics_agent.ini /etc/php/7.4/fpm/conf.d/appdynamics_agent.ini
RUN chmod 755 /etc/php/7.4/fpm/conf.d/appdynamics_agent.ini

RUN bash -c \
    'echo -e "<?php\n    phpinfo();" > /usr/share/nginx/moodle/index.php' && \
    bash -c \
    'echo -e "[program:php7.4-fpm]\ncommand=/etc/init.d/php7.4-fpm start\n\n[program:nginx]\ncommand=/etc/init.d/nginx start" > /etc/supervisor/conf.d/default.conf'

# Finish startup
#CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/supervisord.conf"]
CMD /opt/appdynamics/php-agent/changenodename.sh
