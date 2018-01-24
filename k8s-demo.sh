

https://github.com/brendandburns/acs-ignite-demos

https://docs.microsoft.com/en-us/cli/azure/install-azure-cli

az login

# linux vms

az group create --name kemvm01-rg --location eastus2

az vm create --name kemvm01 --resource-group kemvm01-rg --image centos

az vm show --name kemvm01 --resource-group kemvm01-rg 

ssh

sudo -s

cat /proc/version
uname -mrs
cat /etc/centos-release

lsmod | grep hv_
rpm -qa | grep hyperv

cat /etc/fstab
blkid

cat /etc/default/grub

# container instances

az group create --name kemci01-rg --location eastus2

az container create --name kemci01 --image nginx --resource-group kemci01-rg --ip-address public

az container show --name kemci01 --resource-group kemci01-rg

az container logs --name kemci01 --resource-group kemci01-rg

az container delete --name kemci01 --resource-group kemci01-rg

# azure container service

az group create --name k8s01-rg --location eastus2

az resource list --resource-group k8s01-rg

az acs create --orchestrator-type=kubernetes --resource-group k8s01-rg --name=k8s01cluster --generate-ssh-keys 

az acs kubernetes install-cli

az acs kubernetes get-credentials --resource-group=k8s01-rg --name=k8s01cluster

kubectl get nodes

kubectl run nginx --image nginx
kubectl get pods
kubectl get svc
kubectl expose deployments nginx --port=80 --type=LoadBalancer
kubectl get svc --watch

az acr create --resource-group=k8s01-rg --name=k8s01registry --sku=Basic --admin-enabled=true

az acr list --resource-group=k8s01-rg --query="[].{acrName:name,acrLoginServer:loginServer}" --output=table
AcrName        AcrLoginServer
-------------  ------------------------
k8s01registry  k8s01registry.azurecr.io

az acr credential show --name=k8s01registry --query=passwords[0].value --output=tsv

docker login --username=k8s01registry --password=<your-acr-credential> k8s01registry.azurecr.io
kubectl create secret docker-registry regsecret --docker-server=<your-registry-server> --docker-username=<your-name> --docker-password=<your-pword> --docker-email=<your-email>
kubectl get secret regsecret --output=yaml

deployment.yaml
apiVersion: v1
kind: Pod
metadata:
  name: private-reg
spec:
  containers:
    - name: private-reg-container
      image: <your-private-image>
  imagePullSecrets:
    - name: regsecret
    
kubectl get pods
kubectl scale --replicas=3 deployment/nginx
kubectl get pods --watch

az acs scale --name=k8s01cluster --resource-group=k8s01-rg --new-agent-count=5

kubectl set image deployment nginx nginx=nginx:alpine
kubectl get rs
kubectl get pods

kubectl rollout history deployments nginx
kubectl rollout undo deployments nginx --to-revision=1

kubectl edit deployments nginx

https://sematext.com/kubernetes/cheatsheet/