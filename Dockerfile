ARG nginx_version=1.15.2

FROM nginx:${nginx_version} as build
RUN apt-get update && apt-get install -y --no-install-suggests \
  luajit-5.1-dev libpam0g-dev zlib1g-dev libpcre3-dev \
  libexpat1-dev git curl build-essential libssl-dev \
  && export NGINX_RAW_VERSION=$(echo $NGINX_VERSION | sed 's/-.*//g') \
  && curl -fSL https://nginx.org/download/nginx-$NGINX_RAW_VERSION.tar.gz -o nginx.tar.gz \
  && tar -zxC /usr/src -f nginx.tar.gz
ARG modules
RUN export NGINX_RAW_VERSION=$(echo $NGINX_VERSION | sed 's/-.*//g') \
  && cd /usr/src/nginx-$NGINX_RAW_VERSION \
  && configure_args="--prefix=/etc/nginx --sbin-path=/usr/sbin/nginx --modules-path=/usr/lib/nginx/modules --conf-path=/etc/nginx/nginx.conf --error-log-path=/var/log/nginx/error.log --http-log-path=/var/log/nginx/access.log --pid-path=/var/run/nginx.pid --lock-path=/var/run/nginx.lock --http-client-body-temp-path=/var/cache/nginx/client_temp --http-proxy-temp-path=/var/cache/nginx/proxy_temp --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp --http-scgi-temp-path=/var/cache/nginx/scgi_temp --user=nginx --group=nginx --with-compat --with-file-aio --with-threads --with-http_addition_module --with-http_auth_request_module --with-http_dav_module --with-http_flv_module --with-http_gunzip_module --with-http_gzip_static_module --with-http_mp4_module --with-http_random_index_module --with-http_realip_module --with-http_secure_link_module --with-http_slice_module --with-http_ssl_module --with-http_stub_status_module --with-http_sub_module --with-http_v2_module --with-mail --with-mail_ssl_module --with-stream --with-stream_realip_module --with-stream_ssl_module --with-stream_ssl_preread_module --with-cc-opt='-g -O2 -fdebug-prefix-map=/data/builder/debuild/nginx-1.15.8/debian/debuild-base/nginx-1.15.8=. -specs=/usr/share/dpkg/no-pie-compile.specs -fstack-protector-strong -Wformat -Werror=format-security -Wp,-D_FORTIFY_SOURCE=2 -fPIC' --with-ld-opt='-specs=/usr/share/dpkg/no-pie-link.specs -Wl,-z,relro -Wl,-z,now -Wl,--as-needed -pie'"; IFS=','; \
  for module in ${modules}; do \
  module_repo=$(echo $module | sed -E 's@^(((https?|git)://)?[^:]+).*@\1@g'); \
  module_tag=$(echo $module | sed -E 's@^(((https?|git)://)?[^:]+):?([^:/]*)@\4@g'); \
  dirname=$(echo "${module_repo}" | sed -E 's@^.*/|\..*$@@g'); \
  git clone "${module_repo}"; \
  cd ${dirname}; \
  if [ -n "${module_tag}" ]; then git checkout "${module_tag}"; fi; \
  cd ..; \
  configure_args="${configure_args} --add-dynamic-module=./${dirname}"; \
  done; unset IFS \
  && eval ./configure ${configure_args} \
  && make modules \
  && mkdir /modules \
  && cp $(pwd)/objs/*.so /modules

FROM nginx:${nginx_version}-alpine
COPY --from=build /modules/* /etc/nginx/modules/
RUN for i in 0 1 2 3 4 5 6 7 8 9; do mkdir /tmp/$i && chown nginx /tmp/$i ; done