
FROM nginx:stable

COPY website/index.html website/style.css /usr/share/nginx/html/
COPY default.conf /etc/nginx/conf.d/default.conf

EXPOSE 80