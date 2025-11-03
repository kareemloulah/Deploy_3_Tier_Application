FROM nginx:1.29.2

COPY nginx.conf /etc/nginx/nginx.conf

COPY ./ssl/* /etc/nginx/certs/

EXPOSE 443

CMD ["nginx", "-g", "daemon off;"]