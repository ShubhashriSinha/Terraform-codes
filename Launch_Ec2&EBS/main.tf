provider "aws" {
  region = "ap-south-1"
  profile = "default"
}

resource "aws_instance" "os1" {
  ami = "ami-010aff33ed5991201"
  instance_type = "t2.micro"
  tags = {
    Name = "my-terraform-os"
  }
}

output "my_public_ip" {
  value = aws_instance.os1.public_ip
}
output "my_az" {
  value = aws_instance.os1.availability_zone
}

resource "aws_ebs_volume" "ebs" {
  availability_zone = aws_instance.os1.availability_zone
  size              = 1

  tags = {
    Name = "tf-ebs1"
  }
}

resource "aws_volume_attachment" "ebs_att" {
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.ebs.id
  instance_id = aws_instance.os1.id
}