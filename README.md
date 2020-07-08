### Introduction  
This script is designed to block IP addresses identified as malicious and found in Apache logs.  
  
Malicious IP address is defined as:  
 - one accessing application path, which does not belong to the application;  
 - one already listed in file *iptablesmgr/ip_maliceous*.
  
Script uses known application GET paths stored in file *paths_get*.  
Script uses known application POST paths stored in file *paths_post*.  
Regular expressions, such as /build/[/_.\,~+a-zA-Z.0-9-]* can be used for paths definitions. Regular expressions used for paths definitions are plugged into Linux sed command, and therefore must follow several conventions.
* Characters `/`, `_`, `.`, `\`, `,`, `~`, `+` must be at the beginning of the bracketed expression.
* Characters for space and tab must be spelled as ANSI C escaped sequence: `\s` and `\t` respectively.
  
Script uses apache log file which has been saved in the standard 'combined' format. More details on this format can be found here: [https://httpd.apache.org/docs/2.4/logs.html](https://httpd.apache.org/docs/2.4/logs.html).
  
Script will produce new or add to existing *ip_maliceous* file in *iptablesmgr* directory. The file is a simple list of ip addresses. The script  will use iptables utility and will import these addresses into its own chain called IPGUARD.  
  
New addresses in the *ip_maliceous* files will be added without duplication. In this way, you can have a pre-determined list of maliceous addresses to start. Also, if there are existing ip addresses in the IPGUARD chain, they will not be duplicated or erased. Everything is exported from the chain first, added to the maliceous list, deduped, and then re-imported back.  
The only argument to the script is path to apache log file, which needs to have read permissions. Example: 
```bash
./iptablesmgr /var/log/apache2/test_site-access.log
```
  
  
### Usage  
#### Check requests identified as maliceous:
To fine-tune regular expressions for the legal paths, run the script with -i option. The option takes no arguments and will stop the script after *requests_maliceous* file is generated. You can inspect it with:  
```bash  
grep -rne LEGAL_PATH_IN_QUESTION iptablesmgr/requests_maliceous
```  
This way you can see if your LEGAL_PATH_IN_QUESTION has made it to the maliceous list.  

#### Run inside container:
This example emphasizes use of Linux capabilities for the default root user inside the container. Without these capabilities, manipulations of iptables will not work.
```bash  
docker run --rm -it --cap-add=NET_ADMIN --cap-add=SYS_ADMIN iptablesmgr:latest  
```

#### Process Apache log archives:
If you have several logs archived in apache directory, you can do the following:
```bash
cp /var/log/apache2/access_log-*.gz .
for FILE in access_log-*.gz; do gzip -d $FILE; done
for FILE in access_log*; do sudo ./iptablesmgr.sh $FILE; done
```
