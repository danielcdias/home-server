# Redirecionamento HTTP para HTTPS
server {
    listen 80;
    server_name ${SERVER_HOSTNAME} ~.${SERVER_HOSTNAME};
    
    # Redirecionar tudo para HTTPS
    return 301 https://$host$request_uri;
}

# Servidor HTTPS para a página inicial
server {
    listen 443 ssl;
    server_name ${SERVER_HOSTNAME};
    
    # Certificados
    ssl_certificate /etc/nginx/ssl/${SERVER_HOSTNAME}.crt;
    ssl_certificate_key /etc/nginx/ssl/${SERVER_HOSTNAME}.key;
    
    # Configurações SSL
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;

    root /var/www/html;
    index index.html;
}

# Proxy para o Pi-hole (pihole.${SERVER_HOSTNAME}.${DOMAIN_SUFFIX})
server {
    listen 443 ssl;
    server_name pihole.${SERVER_HOSTNAME}.${DOMAIN_SUFFIX};
    
    ssl_certificate /etc/nginx/ssl/${SERVER_HOSTNAME}.crt;
    ssl_certificate_key /etc/nginx/ssl/${SERVER_HOSTNAME}.key;
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;

    location / {
        proxy_pass http://pihole:80;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

# Proxy para o Home Assistant (ha.${SERVER_HOSTNAME}.${DOMAIN_SUFFIX})
server {
    listen 443 ssl;
    server_name ha.${SERVER_HOSTNAME}.${DOMAIN_SUFFIX};
    
    ssl_certificate /etc/nginx/ssl/${SERVER_HOSTNAME}.crt;
    ssl_certificate_key /etc/nginx/ssl/${SERVER_HOSTNAME}.key;
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;

    location / {
        proxy_pass http://homeassistant:8123;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}

# Proxy para o Komodo (komodo.${SERVER_HOSTNAME}.${DOMAIN_SUFFIX})
server {
    listen 443 ssl;
    server_name komodo.${SERVER_HOSTNAME}.${DOMAIN_SUFFIX};
    
    ssl_certificate /etc/nginx/ssl/${SERVER_HOSTNAME}.crt;
    ssl_certificate_key /etc/nginx/ssl/${SERVER_HOSTNAME}.key;
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;

    location / {
        proxy_pass http://komodo-core:9120;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}

# Proxy para o Webmin (webmin.${SERVER_HOSTNAME}.${DOMAIN_SUFFIX})
server {
    listen 443 ssl;
    server_name webmin.${SERVER_HOSTNAME}.${DOMAIN_SUFFIX};
    
    ssl_certificate /etc/nginx/ssl/${SERVER_HOSTNAME}.crt;
    ssl_certificate_key /etc/nginx/ssl/${SERVER_HOSTNAME}.key;
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;

    # Reescreve WebSockets inseguros
    sub_filter 'ws://' 'wss://';
    sub_filter_once off;
    sub_filter_types *;
    
    location / {
        proxy_pass http://host.docker.internal:10000;
        
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $host;
        
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        
        proxy_redirect http://$host:10000/ https://$host/;
    }
}
