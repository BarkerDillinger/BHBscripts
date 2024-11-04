The `exeBuildBHB.sh` script is intended to be used in conjunction with the [**Black Hat Bash** book published by No Starch Press](https://nostarch.com/black-hat-bash), which provides comprehensive insights into advanced Bash scripting techniques and their applications in security contexts. This script facilitates network scanning to identify live hosts and logs the results, making it a valuable tool for practitioners looking to enhance their cybersecurity skills. Critical files associated with the Docker container installation, which are discussed in the book, must be retrieved from the publisher's site and can also be found on the associated [GitHub repository](https://github.com/dolevf/Black-Hat-Bash). Additional information detailing the lab environment is available both on the GitHub site and within the book, offering readers practical guidance on setting up and utilizing the scripts effectively. The [**Black Hat Bash**](https://nostarch.com/black-hat-bash) book is highly recommended for anyone serious about mastering Bash scripting, as it provides not only theoretical knowledge but also practical applications, making it a worthwhile investment for both beginners and experienced users in the field of cybersecurity.
### Configure the Lab Environment
Configure Docker-CE Sources
```sh
lsb_release -a

sudo apt install apt-transport-https ca-certificates curl gnupg

printf '%s\n' "deb https://download.docker.com/linux/debian/ bookworm stable" | sudo tee /etc/apt/sources.list.d/docker-ce.list

curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/docker-ce-archiver-keyring.gpg

sudo apt install docker-ce docker-ce-cli containerd.io -y

sudo docker compose --help

sudo systemctl enable docker --now
```

```sh
Synchronizing state of docker.service with SysV service script with /lib/systemd/systemd-sysv-install.
Executing: /lib/systemd/systemd-sysv-install enable docker

systemctl status docker

** Expected Output **
● docker.service - Docker Application Container Engine
     Loaded: loaded (/lib/systemd/system/docker.service; enabled; preset: enabled)
     Active: active (running) since Mon 2024-10-28 14:05:30 MST; 1min 28s ago
TriggeredBy: ● docker.socket
       Docs: https://docs.docker.com
   Main PID: 66791 (dockerd)
      Tasks: 12
     Memory: 27.3M
        CPU: 768ms
     CGroup: /system.slice/docker.service
             └─66791 /usr/bin/dockerd -H fd:// --containerd=/run/containerd/containerd.sock
```

**Add $USER to the docker group and use the BASH Shell:**
```sh
sudo usermod -aG docker $USER -s /bin/bash
```

**Clone the Black Hat Bash REPO from github:**
```sh
git clone https://github.com/dolevf/Black-Hat-Bash.git

cd /Black-Hat-Bash/lab
```

**Build the Lab Environment:**
```sh
make help

Usage: make deploy | teardown | clean | rebuild | status | init | help

deploy   | build images and start containers
teardown | stop containers (shutdown lab)
rebuild  | rebuilds the lab from scratch (clean and deploy)
clean    | stop and delete containers and images
status   | check the status of the lab
init     | build everything (containers and hacking tools)
help     | show this help message

sudo make deploy
```

>[NOTE!] Note:
>use `tail -f /var/log/lab-install.log` to see the installation process of the lab
>
>If SSH is being used to access a remote host for the deployment `tmux` can provide multiple tabs within a remote host.

**Test Lab and List the Docker Containers:**
```sh
sudo make test 
Lab is up.

docker ps --format "{{.Names}}"
p-web-02
p-web-01
p-jumpbox-01
p-ftp-01
c-db-02
c-backup-01
c-redis-01
c-db-01



```
>[NOTE!] Note: the `make status` command is identical to `make test`

**Docker Network:**
View the new network with `ip addr | grep "br_"`. This will display the newly created docker network.
```sh
ip addr | grep "br_"

118: br_public: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default 
    inet 172.16.10.1/24 brd 172.16.10.255 scope global br_public
119: br_corporate: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default 
    inet 10.1.0.1/24 brd 10.1.0.255 scope global br_corporate
121: veth726578d@if120: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue master br_corporate state UP group default 
123: veth61eb890@if122: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue master br_public state UP group default 
125: veth3dfcf72@if124: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue master br_public state UP group default 
127: veth73ec583@if126: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue master br_corporate state UP group default 
129: veth9edd2ec@if128: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue master br_public state UP group default 
131: vethe600ea2@if130: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue master br_corporate state UP group default 
133: vethd64d35e@if132: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue master br_corporate state UP group default 
135: vethf5392ce@if134: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue master br_corporate state UP group default 
137: veth2e5c830@if136: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue master br_public state UP group default 
139: vetha9868df@if138: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue master br_corporate state UP group default
```

### Setup and Teardown of the Lab
#### Setup the Lab
```sh
sudo make deploy
```
#### Shutdown the Lab
```sh
sudo make teardown
```
#### Remove the Lab
Completely remove the Lab Environment from the System
```sh
sudo make clean
```
#### Rebuild the Lab
Redeploy the Lab Environment is Removed for Repairs
```sh
sudo make rebuild
```

### Accessing the Machines
###### sudo docker exec-it \< Machine Name \> bash
p-web-02, p-web-01, p-jumpbox-01, p-ftp-01, c-db-02, c-backup-01, c-redis-01, c-db-01 - `docker ps --format "{{.Names}}"`

```sh
sudo docker exec -it p-web-02 bash
root@p-web-02:/var/www/html# ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host 
       valid_lft forever preferred_lft forever
158: eth1@if159: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default 
    link/ether 02:42:0a:01:00:0b brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 10.1.0.11/24 brd 10.1.0.255 scope global eth1
       valid_lft forever preferred_lft forever
160: eth0@if161: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default 
    link/ether 02:42:ac:10:0a:0c brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 172.16.10.12/24 brd 172.16.10.255 scope global eth0
       valid_lft forever preferred_lft forever
root@p-web-02:/var/www/html# 

```


### Execute Build Script
```sh
#!/bin/bash

if [[ "$EUID" -ne 0 ]]; then
	echo "This script reqires root / sudo to function"; exit 1
fi

cd /home/bhb/Documents/Black-Hat-Bash/lab || { echo "Directory Not Found"; exit 1;}
output=$(make test 2>&1)

if [[ "$output" == *"Lab is up"* ]]; then
	echo "Lab is up"
else
	echo "Deploying Lab Environment"
	make deploy
fi

docker ps --format "{{.Names}}\t{{.Networks}}" | tail -n +2 | while read -r name network; do
    # Get IP addresses and join with a space if there are multiple
    ip=$(docker inspect -f '{{range $net, $conf := .NetworkSettings.Networks}}{{$conf.IPAddress}} {{end}}' "$name" | xargs)
    printf "%-20s %-20s\n" "$name" "$ip"
done

cd /home/bhb/Documents/Black-Hat-Bash/lab && exec bash
```
