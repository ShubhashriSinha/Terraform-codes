provider "aws" {
  region = "ap-south-1"
  access_key = "<access-key>"  
  secret_key = "<Secret-key>"

}

resource "aws_ami_launch_permission" "share" {
  count = "${length(var.account_ids)}"
  image_id   = "${var.ami_id}"
  account_id = "${var.account_ids[count.index]}"
}

resource "null_resource" "main" {

  provisioner "local-exec" {
    command = "aws rds modify-db-snapshot-attribute --db-snapshot-identifier <your database identifier> --attribute-name restore --values-to-add <account id> "
  }

}