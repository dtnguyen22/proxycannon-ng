variable "aws_priv_key" {
  default = "~/.ssh/proxycannon.pem"
}

# number of exit-node instances to launch
variable "nodeCount" {
  default = 5
}

# launch all exit nodes in the same subnet id
# this should be the same subnet id that your control server is in
# you can get this value from the AWS console when viewing the details of the control-server instance
variable "subnet_id" {
  default = "subnet-02933afae921aa3c8"
}
