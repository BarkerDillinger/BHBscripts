### Configure the Lab Environment
Configure Docker-CE Sources
```
lsb_release -a

sudo apt install apt-transport-https ca-certificates curl gnupg

printf '%s\n' "deb https://download.docker.com/linux/debian/ bookworm stable" | sudo tee /etc/apt/sources.list.d/docker-ce.list

curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/docker-ce-archiver-keyring.gpg

sudo apt install docker-ce docker-ce-cli containerd.io -y

sudo docker compose --help

sudo systemctl enable docker --now
```
Synchronizing state of docker.service with SysV service script with /lib/systemd/systemd-sysv-install.
Executing: /lib/systemd/systemd-sysv-install enable docker
```
systemctl status docker
```
Add $USER to the docker group and use the BASH Shell:
```
sudo usermod -aG docker $USER -s /bin/bash
```
Clone the Black Hat Bash REPO from github:
```
git clone https://github.com/dolevf/Black-Hat-Bash.git
cd /Black-Hat-Bash/lab
```
Build the Lab Environment:
```
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
**Note:**
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
**Note:** the `make status` command is identical to `make test`
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
```

