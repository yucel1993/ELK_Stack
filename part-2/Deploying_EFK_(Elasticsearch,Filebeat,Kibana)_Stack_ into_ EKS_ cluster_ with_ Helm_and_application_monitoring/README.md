# Deploying EFK Stack (Elasticsearch, Kibana and Filebeat) with Helm and Microservice Application Logging on the EKS cluster:

Purpose of the this hands-on training is to give students the knowledge of how to install, configure and use EFK Stack on EKS Cluster with Helm and monitoring logs of kubernetes microservice application.

# Steps to Create EKS Cluster

## Part 1 - Installing kubectl and eksctl on Amazon Linux 2023:

### Install kubectl:

- Launch an AWS EC2 instance of Amazon Linux 2023 AMI with security group allowing SSH.

- Connect to the instance with SSH.

- Update the installed packages and package cache on your instance.

```bash
sudo dnf update -y
```

- Download the Amazon EKS vended kubectl binary.

```bash
curl -O https://s3.us-west-2.amazonaws.com/amazon-eks/1.29.0/2024-01-04/bin/linux/amd64/kubectl
```

- Apply execute permissions to the binary.

```bash
chmod +x ./kubectl
```

- Copy the binary to a folder in your PATH. If you have already installed a version of kubectl, then we recommend creating a $HOME/bin/kubectl and ensuring that $HOME/bin comes first in your $PATH.

```bash
mkdir -p $HOME/bin && cp ./kubectl $HOME/bin/kubectl && export PATH=$PATH:$HOME/bin
```

- (Optional) Add the $HOME/bin path to your shell initialization file so that it is configured when you open a shell.

```bash
echo 'export PATH=$PATH:$HOME/bin' >> ~/.bashrc
```

- After you install kubectl , you can verify its version with the following command:

```bash
kubectl version --client
```

### Install eksctl

- Download and extract the latest release of eksctl with the following command.

```bash
curl -sLO "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz"
```

- Move and extract the binary to /tmp folder.

```bash
tar -xzf eksctl_$(uname -s)_amd64.tar.gz -C /tmp && rm eksctl_$(uname -s)_amd64.tar.gz
```

- Move the extracted binary to /usr/local/bin.

```bash
sudo mv /tmp/eksctl /usr/local/bin
```

- Test that your installation was successful with the following command.

```bash
eksctl version
```

## Part 2 - Creating the Kubernetes Cluster on EKS

- If needed create ssh-key with commnad `ssh-keygen -f ~/.ssh/id_rsa`

- Configure AWS credentials. Or you can attach `AWS IAM Role` to your EC2 instance.

```bash
aws configure
```

- Create an EKS cluster via `eksctl`. It will take a while.

```bash
eksctl create cluster \
 --name polo \
 --region us-east-1 \
 --zones us-east-1a,us-east-1b,us-east-1c \
 --nodegroup-name my-nodes \
 --node-type t2.medium \
 --nodes 2 \
 --nodes-min 2 \
 --nodes-max 3 \
 --version 1.29
 --ssh-access \
 --ssh-public-key  ~/.ssh/id_rsa.pub \
 --managed
```

or 

```bash
eksctl create cluster --region us-east-1 --zones us-east-1a,us-east-1b,us-east-1c --node-type t2.medium --nodes 2 --nodes-min 2 --nodes-max 3 --version 1.29  --name polo
```

- Explain the deault values. 

```bash
eksctl create cluster --help
```

- Show the aws `eks service` on aws management console and explain `eksctl-polo-cluster` stack on `cloudformation service`.

## Dynamic Volume Provisionining

### The Amazon Elastic Block Store (Amazon EBS) Container Storage Interface (CSI) driver

- The Amazon Elastic Block Store (Amazon EBS) Container Storage Interface (CSI) driver allows Amazon Elastic Kubernetes Service (Amazon EKS) clusters to manage the lifecycle of Amazon EBS volumes for persistent volumes.

- The Amazon EBS CSI driver isn't installed when you first create a cluster. To use the driver, you must add it as an Amazon EKS add-on or as a self-managed add-on. 

- Install the Amazon EBS CSI driver. For instructions on how to add it as an Amazon EKS add-on, see Managing the [Amazon EBS CSI driver as an Amazon EKS add-on](https://docs.aws.amazon.com/eks/latest/userguide/managing-ebs-csi.html).

### Creating an IAM OIDC provider for your cluster

- To use AWS EBS CSI, it is required to have an AWS Identity and Access Management (IAM) OpenID Connect (OIDC) provider for your cluster. 

- Determine whether you have an existing IAM OIDC provider for your cluster. Retrieve your cluster's OIDC provider ID and store it in a variable.

```bash
oidc_id=$(aws eks describe-cluster --name polo --query "cluster.identity.oidc.issuer" --output text | cut -d '/' -f 5)
```

- Determine whether an IAM OIDC provider with your cluster's ID is already in your account.

```bash
aws iam list-open-id-connect-providers | grep $oidc_id
```
If output is returned from the previous command, then you already have a provider for your cluster and you can skip the next step. If no output is returned, then you must create an IAM OIDC provider for your cluster.

- Create an IAM OIDC identity provider for your cluster with the following command. Replace polo with your own value.

```bash
eksctl utils associate-iam-oidc-provider --region=us-east-1 --cluster=polo --approve
```

### Creating the Amazon EBS CSI driver IAM role for service accounts

- The Amazon EBS CSI plugin requires IAM permissions to make calls to AWS APIs on your behalf. 

- When the plugin is deployed, it creates and is configured to use a service account that's named ebs-csi-controller-sa. The service account is bound to a Kubernetes clusterrole that's assigned the required Kubernetes permissions.

#### To create your Amazon EBS CSI plugin IAM role with eksctl

- Create an IAM role and attach the required AWS managed policy with the following command. Replace polo with the name of your cluster. The command deploys an AWS CloudFormation stack that creates an IAM role, attaches the IAM policy to it, and annotates the existing ebs-csi-controller-sa service account with the Amazon Resource Name (ARN) of the IAM role.

```bash
eksctl create iamserviceaccount \
    --region us-east-1 \
    --name ebs-csi-controller-sa \
    --namespace kube-system \
    --cluster polo \
    --role-name AmazonEKS_EBS_CSI_DriverRole \
    --role-only \
    --attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy \
    --approve
```

### Adding the Amazon EBS CSI add-on

#### To add the Amazon EBS CSI add-on using eksctl

- Run the following command. Replace polo with the name of your cluster, 111122223333 with your account ID, and AmazonEKS_EBS_CSI_DriverRole with the name of the IAM role created earlier.

```bash
eksctl create addon --region us-east-1 --name aws-ebs-csi-driver --cluster polo --service-account-role-arn arn:aws:iam::046402772087:role/AmazonEKS_EBS_CSI_DriverRole --force
```


## Steps to Install Helm:
--------------------------------

```bash
curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
helm version
```


## Part-3 Install EFK stack in EKS cluster using Helm:

- Create  namespace with the name of efk.

```bash
kubectl create ns efk
kubectl get ns
```
- Install ELK Stack helm repo into your local repo with helm command.

```bash
helm repo add elastic https://helm.elastic.co
```
- Update your repo after installation.

```bash
helm repo update
```
- Liste your repo packages.

```bash
helm repo ls
```

- List your helm chart and manifest files.

```bash
helm search repo
```

## Part-4 EFK Stack (Elasticsearch, Filebeat, Kibana) installation and configuration in EKS cluster with Helm:

### Installation and configuration of Elasticsearch via Helm into EKS Cluster:

- Show your elastic/elasticsearch values and save it as elasticsearch.values file in order to make some configuration.

```bash
helm show values elastic/elasticsearch >> elasticsearch.values
```

```bash
helm install elasticsearch elastic/elasticsearch -f elasticsearch.values -n efk
```

```bash
helm ls -n efk
```

```bash
kubectl get all -n efk
```

### Installation and configuration of Kibana via Helm into EKS Cluster:

```bash
helm show values elastic/kibana >> kibana.values
```
- Change the values configuration with LoadBalancer.

```bash
vi kibana.values
```
*****************
# update service type: LoadBalancer
*****************

```bash
helm install kibana elastic/kibana -f kibana.values -n efk
```

```bash
kubectl get all -n efk
```

******************
# KibanaLoadBalancer url: aad89579c647046619ae4d6efb9e631d-1736015238.us-east-1.elb.amazonaws.com:5601
******************

- To login kibana:

```yaml
Username: elastic
Password: The output of following command
kubectl -n efk get secret elasticsearch-master-credentials -ojsonpath='{.data.password}' | base64 -d
```

### Installation and configuration of Filebeat via Helm into EKS Cluster:

- Installation of Filebeat via Helm.

```bash
helm install filebeat elastic/filebeat -n efk
```

```bash
kubectl get all -n efk
```

```bash
kubectl get pvc -n efk
```

## Part-5 Kibana Dashboard configuration and sample app log monitoring:

### Dashboard configuration and index pattern creation:

* logs: system logs default

* Discover: create a data view
  
  - filebeat-*

  - select @timestamp

  - create an index pattern.

### Deployment of sample applications into EKS kubernetes environment:

```bash
kubectl apply -f php_apache.yaml
```

```bash
kubectl apply -f to_do.yaml
```

```bash
kubectl get all
```

* * * Reaching both of the applications from browser. 

- Open TCP port for 30001-30002 of EKS node and copy public URL in order to reach applications  from browser. 


## Kubernetes Logging commands from terminal:

*********************                               *************                               
kubectl logs my-pod                                 # dump pod logs (stdout)
kubectl logs -l name=myLabel                        # dump pod logs, with label name=myLabel (stdout)
kubectl logs my-pod --previous                      # dump pod logs (stdout) for a previous instantiation of a container
kubectl logs my-pod -c my-container                 # dump pod container logs (stdout, multi-container case)
kubectl logs -l name=myLabel -c my-container        # dump pod logs, with label name=myLabel (stdout)
kubectl logs my-pod -c my-container --previous      # dump pod container logs (stdout, multi-container case) for a previous instantiation of a container
kubectl logs -f my-pod                              # stream pod logs (stdout)
kubectl logs -f my-pod -c my-container              # stream pod container logs (stdout, multi-container case)
kubectl logs -f -l name=myLabel --all-containers    # stream all pods logs with label name=myLabel (stdout)
***********************

- Delete the cluster

```bash
eksctl get cluster --region us-east-1
```
- You will see an output like this

```text
NAME            REGION
polo      us-east-1
```
```bash
eksctl delete cluster polo --region us-east-1
```