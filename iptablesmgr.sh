#! /bin/bash -

# INIT
APACHE_ENV_VARS='/etc/apache2/envvars'
PATHS_GET=paths_get
PATHS_POST=paths_post
APP_DIR=iptablesmgr
REQUESTS_MALICEOUS=requests_maliceous
IP_MALICEOUS=ip_maliceous
IP_LEGAL=ip_legal
CHAIN=IPGUARD

getopts 'i' INSPECT

# TODO: include help option

if [ $INSPECT == 'i' ]; then
  APACHE_LOG=$2
fi
if [ $INSPECT == '?' ]; then
  APACHE_LOG=$1
fi

print_error () {
  echo '--->ERROR:' $1
  echo $2
}

import_ip_maliceous () {
  echo Importing rules...
  touch  ${APP_DIR}/${IP_MALICEOUS}
  while read; do
    iptables -I $1 -p all -j DROP -s ${REPLY}
    # echo iptables -I $1 -p all -j DROP -s ${REPLY}
  done < ${APP_DIR}/${IP_MALICEOUS}
}

dedup () {
  sort -o ${APP_DIR}/temp $1
  cat ${APP_DIR}/temp | uniq > $1
  rm ${APP_DIR}/temp
}


# CONFIGURE
# check if iptables is installed
command -v iptables >/dev/null 2>&1 || { print_error "Please install iptables. Aborting."; exit 1; }

# TODO: include check for user's capabilities, i.e. if they can run iptables

#if [ -f ${APACHE_ENV_VARS} ]; then
#  source $APACHE_ENV_VARS
#fi


if [ ! -f ${APP_DIR}/${PATHS_GET} ]; then
  print_error 'File paths_get could not be found' 'It is needed to define legal application paths for GET requests'
  exit
fi

if [ ! -f ${APP_DIR}/${PATHS_POST} ]; then
  print_error 'File paths_post could not be found' 'It is needed to define legal application paths for POST requests'
  exit
fi

if [ ! -f ${APP_DIR}/${PATHS_MALICEOUS} ]; then
  touch ${APP_DIR}/${PATHS_MALICEOUS}
fi

if [ -z ${APACHE_LOG} ]; then
  print_error 'Please specify full path to the apache log' 'Example: /var/log/apache2/access.log'
  exit 1
fi

if [ ! -f ${APACHE_LOG} ]; then
  print_error 'Could not find apache log.' "Looked for ${APACHE_LOG}"
  exit 1
fi

# Remove commented and empty lines
FILTER_GET='/^#/d;/^$/d;'
sed -re ${FILTER_GET} ${APP_DIR}/${PATHS_GET} > ${APP_DIR}/temp
while read; do
  FILTER_GET+="\-GET\s${REPLY}\s-d;"
done < ${APP_DIR}/temp

FILTER_POST='/^#/d;/^$/d;'
sed -re ${FILTER_POST} ${APP_DIR}/${PATHS_POST} > ${APP_DIR}/temp
while read; do
  FILTER_POST+="\-POST\s${REPLY}\s-d;"
done < ${APP_DIR}/temp

if [ ! -d ${APP_DIR} ]; then
  mkdir ${APP_DIR}
fi

if [ ! -f ${APP_DIR}/${REQUESTS_MALICEOUS} ]; then
  touch ${APP_DIR}/${REQUESTS_MALICEOUS}
else
  : > ${APP_DIR}/${REQUESTS_MALICEOUS}
fi


# EXECUTE
cp ${APACHE_LOG} ${APP_DIR}/${REQUESTS_MALICEOUS}

# Remove legal ip addresses from Apache log first. They can have any path
if [ -f ${APP_DIR}/${IP_LEGAL} ]; then
  while read; do
    # echo ${REPLY}
    sed -ire "/^${REPLY}\s/d" ${APP_DIR}/${REQUESTS_MALICEOUS}
  done < ${APP_DIR}/${IP_LEGAL}
fi

# use sed and the created filter expressions for GET and POST requests  to remove legal paths, save the rest in assumed maliceous requests
sed -i -re $FILTER_GET ${APP_DIR}/${REQUESTS_MALICEOUS}
sed -i -re $FILTER_POST ${APP_DIR}/${REQUESTS_MALICEOUS}
# Further nix lines which request root path "/"
sed -i -e '\-GET\s/\sHTTP/1-d' ${APP_DIR}/${REQUESTS_MALICEOUS}
# Nix lines that don't have request type in them. These are requests from local services to apache.
sed -i -e '/"-"\s408/d' ${APP_DIR}/${REQUESTS_MALICEOUS}

if [ $INSPECT == 'i' ]; then
  echo '*** -------- ***'
  echo Please inspect the file ${APP_DIR}/${REQUESTS_MALICEOUS} for possible legal paths to be present
  echo 'You can use `grep -rne LEGAL_PATH_IN_QUESTION '${APP_DIR}/${REQUESTS_MALICEOUS}'`'
  echo '*** COMPLETE ***'
  exit 0
fi

# Create list of malicious IP addresses and remove duplicates:
cut -d ' ' -f1 ${APP_DIR}/${REQUESTS_MALICEOUS} | sort | uniq >> ${APP_DIR}/${IP_MALICEOUS}
dedup ${APP_DIR}/${IP_MALICEOUS}

# Check if chain exists in IP tables. If not, create it
iptables -S $CHAIN > /dev/null 2>&1
if [ $? -gt 0 ]; then
  echo No chain $CHAIN. Will create.
  iptables -N $CHAIN
  import_ip_maliceous $CHAIN
  iptables -I INPUT 1 -j $CHAIN
else
  echo Found chain $CHAIN
  iptables -S $CHAIN | sed -e '1d' | cut -d ' ' -f4 | sed -e 's/\/32//g' | sort | uniq >> ${APP_DIR}/${IP_MALICEOUS}
  dedup ${APP_DIR}/${IP_MALICEOUS}
  iptables -F $CHAIN
  import_ip_maliceous $CHAIN
fi

# TODO in the list identify which IP addresses were new for this run
echo '*** -------- ***'
echo Your current chain $CHAIN has these rules now:
iptables --line-numbers -v -nL $CHAIN
echo '*** COMPLETE ***'
