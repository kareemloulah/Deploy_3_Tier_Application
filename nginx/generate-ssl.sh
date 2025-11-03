#!/bin/bash

# === CONFIGURATION ===
SSL_DIR="/ssl"
DAYS_VALID=365
COUNTRY="EG"
STATE="CAIRO"
CITY="GIZA"
ORG="MyCompany"
ORG_UNIT="IT"
COMMON_NAME="localhost"

# === SCRIPT START ===

echo "🔐 Self-Signed SSL Generator for Nginx"
echo "---------------------------------------"

read -p "Enter domain name (default: localhost): " DOMAIN
DOMAIN=${DOMAIN:-$COMMON_NAME}

# Create directory if missing
sudo mkdir -p $SSL_DIR

CERT_FILE="$SSL_DIR/$DOMAIN.crt"
KEY_FILE="$SSL_DIR/$DOMAIN.key"

echo "➡️  Generating certificate for domain: $COMMON_NAME"
echo "➡️  Saving to: $CERT_FILE and $KEY_FILE"

# Generate self-signed certificate
sudo openssl req -x509 -nodes -days $DAYS_VALID -newkey rsa:2048 \
  -keyout "$KEY_FILE" \
  -out "$CERT_FILE" \
  -subj "/C=$COUNTRY/ST=$STATE/L=$CITY/O=$ORG/OU=$ORG_UNIT/CN=$DOMAIN"

# Adjust permissions
sudo chmod 644 "$KEY_FILE"
sudo chmod 644 "$CERT_FILE"

echo "✅ SSL certificate generated successfully!"
echo ""
echo "Certificate: $CERT_FILE"
echo "Key:         $KEY_FILE"
echo ""

