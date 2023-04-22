#!/bin/bash
yum -y update

###
# INSTALL THE CAFE APP
###
amazon-linux-extras install -y lamp-mariadb10.2-php7.2 php7.2
yum -y install httpd mariadb-server wget nmap
systemctl enable httpd
systemctl start httpd

echo '<html><h1>Hello From Your Web Application Server!</h1></html>' > /var/www/html/index.html
find /var/www -type d -exec chmod 2775 {} \;
find /var/www -type f -exec chmod 0664 {} \;
echo '<?php phpinfo(); ?>' > /var/www/html/phpinfo.php
usermod -a -G apache ec2-user
chown -R ec2-user:apache /var/www
chmod 2775 /var/www

wget https://aws-tc-largeobjects.s3-us-west-2.amazonaws.com/ILT-TF-200-ACACAD-20-EN/Module-9-Challenge-Lab/cafe.tar.gz
tar -zxvf cafe.tar.gz -C /var/www/html/

