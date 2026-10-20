# Static site served by unprivileged nginx on port 8080 (Cloud Run).
FROM nginxinc/nginx-unprivileged:1.27-alpine

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY index.html hero.jpg portrait.jpg /usr/share/nginx/html/

EXPOSE 8080
