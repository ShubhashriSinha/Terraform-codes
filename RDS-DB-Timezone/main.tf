provider "aws" {
  region = "ap-south-1"
  profile = "default"

}

resource "aws_db_parameter_group" "para-gp" {
  name   = "time-zone-terraform"
  family = "mysql5.7"

  parameter {
    name  = "time_zone"
    value = "Asia/Calcutta"
  }
}

resource "aws_db_instance" "db_instance" {
  instance_class = "db.t2.micro"
  copy_tags_to_snapshot = true
  publicly_accessible = true
  skip_final_snapshot = true
  parameter_group_name = aws_db_parameter_group.para-gp.name
  apply_immediately = true
}


resource "null_resource" "pending-reboot" {

  triggers = {
    db_host = "${aws_db_instance.db_instance.parameter_group_name}"
  }

  provisioner "local-exec" {
    command = "aws rds reboot-db-instance --db-instance-identifier ${aws_db_instance.db_instance.identifier} && aws rds wait db-instance-available --db-instance-identifier ${aws_db_instance.db_instance.identifier}"
  }
}