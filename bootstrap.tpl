#! /bin/bash
sudo apt-get upgrade -y && apt-get update -y && apt-get install awscli -y && apt-get install apache2 -y && apt-get install stress -y && service apache2 start 
sudo echo "public ip is $(curl http://169.254.169.254/latest/meta-data/public-ipv4), " >> hung.txt
sudo echo "instance id is $(curl  http://169.254.169.254/latest/meta-data/instance-id)," >> hung.txt
sudo echo "instance-type is $(curl  http://169.254.169.254/latest/meta-data/instance-type) " >> hung.txt
sudo cat hung.txt > /var/www/html/index.html