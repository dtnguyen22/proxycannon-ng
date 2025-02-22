provider "aws" {
  shared_credentials_file = "~/.aws/credentials"
  region = "ca-central-1"
}

resource "aws_instance" "exit-node" {
  ami           = "ami-09e2c09f31b90da99"
  instance_type = "t2.nano"
  key_name      = "proxycannon"
  vpc_security_group_ids = ["${aws_security_group.exit-node-sec-group.id}"]
  subnet_id	= "${var.subnet_id}"
  # we need to disable this for internal routing
  source_dest_check	= false
  count		= "${var.nodeCount}"


  tags = {
    Name = "exit-node"
  }

  # upload our provisioning scripts
  provisioner "file" {
    source      = "${path.module}/configs/"
    destination = "/tmp/"

    connection {
      type     = "ssh"
      user     = "ubuntu"
      host = self.public_ip
      private_key = "${file("${var.aws_priv_key}")}"
    }
  }

  # execute our provisioning scripts
  provisioner "remote-exec" {
    script = "${path.module}/configs/node_setup.bash"

    connection {
      type     = "ssh"
      user     = "ubuntu"
      host = self.public_ip
      private_key = "${file("${var.aws_priv_key}")}"
    }
  }

  # modify our route table when we bring up an exit-node
  provisioner "local-exec" {
    command = "sudo ./add_route.bash ${self.private_ip}"
  }

  # modify our route table when we destroy an exit-node
  provisioner "local-exec" {
    when = destroy
    command = "sudo ./del_route.bash ${self.private_ip}"
  }

}

resource "aws_security_group" "exit-node-sec-group" {
  name = "exit-node-sec-group"

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 0
    to_port     = 0 
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


