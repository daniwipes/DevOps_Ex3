provider "aws" {
    region = "us-east-1"
}

locals {
    webserver_ami = "ami-0b5eea76982371e91"
    webserver_instance_type = "t2.micro"
}

resource "tls_private_key" "dev-key" {
    algorithm = "RSA"
    rsa_bits = 4096
}
resource "local_file" "store-private-key" {
    content = "${tls_private_key.dev-key.private_key_openssh}"
    filename = "./private_key.pem"
    file_permission = "600"
}
resource "aws_key_pair" "ssh-key" {
    key_name = "ssh-dev-key"
    public_key = tls_private_key.dev-key.public_key_openssh
}

resource "aws_security_group" "webserver_sg" {
    name = "webserver-sg"
    
    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        
        cidr_blocks = ["0.0.0.0/0"]
    }
    
    egress {
        from_port = 0
        to_port = 0
        protocol = -1
        cidr_blocks = ["0.0.0.0/0"]
    }
    
    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        
        cidr_blocks = ["0.0.0.0/0"]
    }

}

resource "aws_instance" "webserver_instance" {
    ami = local.webserver_ami
    instance_type = local.webserver_instance_type
    vpc_security_group_ids = ["${aws_security_group.webserver_sg.id}"]
    key_name = aws_key_pair.ssh-key.key_name
    
    user_data = <<-EOF
                  #!/bin/bash
                  sudo yum update -y
                  sudo yum install -y httpd
                  sudo systemctl start httpd
                  sudo systemctl enable httpd
                  usermod -aG apache ec2-user
                  wget "my-cute-little-bucket.s3.amazonaws.com/index.html"
                  echo "<html><body><h1>Hello World from $(hostname -f)</h1></body></html>" > /var/www/html/index.html
                EOF
                
    tags = {
        Name = "webserver"
    }
}

resource "aws_s3_bucket" "bucket_instance" {
    bucket = "my-cute-little-bucket"
}

resource "aws_s3_object" "website-upload" {
    bucket = "my-cute-little-bucket"
    key = "index.html"
    source = "./index.html"
}

# backend
terraform {
    backend "s3" {
        bucket = "mei_supa_bucket_oida"
        key = "rev-demo.tf"
        region = "us-east-1"
    }
}

output "public_ip" {
    value = aws_instance.webserver_instance.public_ip
}

output "url" {
    value = "http://${aws_instance.webserver_instance.public_ip}"
}

output "ssh_command" {
    value = "ssh ec2-user@${aws_instance.webserver_instance.public_ip} -i ./private_key.pem"
}

output "bucket_url" {
    value = aws_s3_bucket.bucket_instance.bucket_domain_name
}
