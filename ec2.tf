variable "awsprops" {
    default = {
    region = "eu-central-1"
    vpc = "vpc-038012c6a80998784"
    ami = "ami-018f4111feee6f553"
    itype = "t2.medium"
    subnet = "subnet-08d98c014b9dc2618"
    publicip = true
    keyname = "PEM"
    secgroupname = "bh67sg"
  }
}

provider "aws" {
  region = lookup(var.awsprops, "region")
}

resource "aws_security_group" "bh67sg" {
  name = lookup(var.awsprops, "secgroupname")
  description = lookup(var.awsprops, "secgroupname")
  vpc_id = lookup(var.awsprops, "vpc")

  // ssh, https, rdp, postgres
  ingress {
    from_port = 22
    protocol = "tcp"
    to_port = 22
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    from_port = 443
    protocol = "tcp"
    to_port = 443
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    from_port = 3389
    protocol = "tcp"
    to_port = 3389
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    from_port = 5432
    protocol = "tcp"
    to_port = 5432
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }
    
    tags = merge(
    var.tags
  )
    
}

resource "aws_instance" "bh67" {
  ami = lookup(var.awsprops, "ami")
  instance_type = lookup(var.awsprops, "itype")
  subnet_id = lookup(var.awsprops, "subnet") #FFXsubnet2
  associate_public_ip_address = lookup(var.awsprops, "publicip")
  key_name = lookup(var.awsprops, "keyname")

user_data = <<EOF
#! /bin/bash
echo "I was here">/var/tmp/greetings.txt
curl -LO https://storage.googleapis.com/kubernetes-release/release/`curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt`/bin/linux/amd64/kubectl >> /var/tmp/kubectl.download 2>&1
chmod 755 ./kubectl
mv ./kubectl /usr/local/bin/kubectl
kubectl version --client -o json >>/var/tmp/kubectl.version 2>&1
yum -y install docker >>/var/tmp/yum.docker 2>&1
usermod -aG docker ec2-user
curl -Lo minikube https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64 >> /var/tmp/minikube.download 2>&1
chmod 755 minikube
mv minikube /usr/local/bin/
minikube version >>/var/tmp/minikube.version 2>&1
systemctl start docker >> /var/tmp/docker.start 2>&1
systemctl enable docker >> /var/tmp/docker.start 2>&1
systemctl status docker >> /var/tmp/docker.status 2>&1
su ec2-user -c 'minikube start --driver=docker --container-runtime=containerd >> /var/tmp/minikube.start 2>&1; ./run.sh'
yum install git -y 2>&1
git clone https://bernd-hohmann:mygithubpat@github.vodafone.com/bernd-hohmann/minikube.git 2>&1
cd minikube/Kapitel_6 2>&1
pwd > /tmp/whereami 2>&1
#da nicht im hintergrund gestartet
#while ps -ef | grep "[m]inikube start" 2>&1 ; do sleep 1 ; done
#while ! su ec2-user -c "kubectl describe pods -A" ; do su ec2-user -c "kubectl describe pods -A >> /tmp/describe_pods 2>&1 && sleep 10" ; done
su ec2-user -c "minikube addons enable ingress"
su ec2-user -c "minikube addons enable dashboard"
su ec2-user -c "minikube addons enable metrics-server"
su ec2-user -c "kubectl apply -f mongodb-configmap.yaml 2>&1"
su ec2-user -c "kubectl apply -f mongodb-secret.yaml 2>&1"
su ec2-user -c "kubectl apply -f mongodb.yaml 2>&1"
su ec2-user -c "kubectl apply -f mongo-express.yaml 2>&1"
#warte bis ready
while ! su ec2-user -c "kubectl get pod | grep ^mongodb | tr -s ' ' | cut -d' ' -f3 | grep Running" ; do sleep 1 ; su ec2-user -c "kubectl get pod | grep ^mongodb" >> /tmp/wait_for_mongoexpress ;  done
while ! su ec2-user -c "kubectl get pod | grep ^mongo-express | tr -s ' ' | cut -d' ' -f3 | grep Running" ; do sleep 1 ; su ec2-user -c "kubectl get pod | grep ^mongo-express" >> /tmp/wait_for_mongoexpress ;  done
su ec2-user -c "kubectl apply -f mongo-express-ingress.yaml 2>&1"
while ! su ec2-user -c "kubectl get ingress | grep ^mongo-express | tr -s ' ' | cut -d' ' -f4 | grep '\.'" ; do sleep 1 ; su ec2-user -c "kubectl get ingress | grep ^mongo-express" >> /tmp/wait_for_mongoexpress ;  done
echo "$( su ec2-user -c "kubectl get ingress | grep ^mongo-express | tr -s ' ' | cut -d' ' -f4 | grep '\.'" ) mongoexpress.com" >> /etc/hosts
EOF


  vpc_security_group_ids = [
    aws_security_group.bh67sg.id
  ]
  
  tags = merge(
    var.tags
  )

  depends_on = [ aws_security_group.bh67sg ]
}


output "ec2instance" {
  value = aws_instance.bh67.public_ip
}
