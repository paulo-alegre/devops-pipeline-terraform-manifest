resource "aws_iam_role" "terraform_role" {
  name = "terraform_role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "jenkins_terraform_attachment" {
  role       = aws_iam_role.terraform_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_iam_instance_profile" "jenkins_terraform_profile" {
  name = "Jenkins-terraform"
  role = aws_iam_role.terraform_role.name
}


resource "aws_security_group" "k8s-sg" {
  name        = "K8s-Security Group"
  description = "Open 22,443,80"

  # Define a single ingress rule to allow traffic on all specified ports
  ingress = [
    for port in [22, 80, 443] : {
      description      = "TLS from VPC"
      from_port        = port
      to_port          = port
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      security_groups  = []
      self             = false
    }
  ]

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "k8s-sg"
  }
}

resource "aws_instance" "k8s" {
  count         = 2
  ami           = "ami-0fa377108253bf620" # Replace with the actual Ubuntu 22.04 AMI
  instance_type = "t2.medium"
  key_name      = "ipau"
  vpc_security_group_ids = [aws_security_group.k8s-sg.id]
  user_data              = templatefile("./install_kube.sh", {})
  iam_instance_profile   = aws_iam_instance_profile.jenkins_terraform_profile.name

  root_block_device {
    volume_size = 10
  }

  tags = {
    Name = "k8s-${count.index + 1}"
  }
}
