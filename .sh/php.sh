#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

echo "Updating package lists..."
sudo apt update

echo "Installing PHP and common extensions..."
sudo apt install -y php php-cli php-common php-curl php-mbstring php-xml

echo "------------------------------"
echo "Installation Complete!"
echo "PHP Version Info:"
wh
echo "------------------------------"

php -S localhost:8000
