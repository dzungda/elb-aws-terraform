provider "aws" {
  region  = var.region
  profile = var.profile
}
data "aws_availability_zones" "available" {}

##############################################################
# Data sources to get VPC, subnets and security group details
##############################################################
data "aws_vpc" "default" {
  tags = {
    Owner       = "user"
    Environment = "dev"
  }
}
resource "random_pet" "this" {
  length = 2
}
data "aws_subnet_ids" "public_subnet" {
    vpc_id = data.aws_vpc.default.id
    tags = {
        Name = "pubsb-terraform-test"
    }
}
data "aws_subnet_ids" "private_subnet" {
  vpc_id = data.aws_vpc.default.id
  tags = {
    Name = "prisb-terraform-test"
  }
}
data "aws_security_group" "default" {
  vpc_id = data.aws_vpc.default.id
  name   = "default"
}
#########################
# S3 bucket for ELB logs
#########################
data "aws_elb_service_account" "main" {}

data "aws_iam_policy_document" "logs" {
  statement {
    actions = [
      "s3:PutObject",
    ]

    principals {
      type        = "AWS"
      identifiers = [data.aws_elb_service_account.main.arn]
    }

    resources = [
      "arn:aws:s3:::elb-logs-${random_pet.this.id}/*",
    ]
  }
}

resource "aws_s3_bucket" "logs" {
  bucket        = "elb-logs-${random_pet.this.id}"
  acl           = "private"
  policy        = data.aws_iam_policy_document.logs.json
  force_destroy = true
}
######
# ELB
######
module "elb" {
    source = "../../modules/terraform-aws-elb/modules/elb"
    name = "elb-terraform-test"
    subnets         = var.subnets_id_list #data.aws_subnet_ids.public_subnet.ids
    security_groups = [data.aws_security_group.default.id]
    internal        = false

    listener = [
        {
        instance_port     = "80"
        instance_protocol = "http"
        lb_port           = "80"
        lb_protocol       = "http"
        },
        {
        instance_port     = "8080"
        instance_protocol = "http"
        lb_port           = "8080"
        lb_protocol       = "http"

        //      Note about SSL:
        //      This line is commented out because ACM certificate has to be "Active" (validated and verified by AWS, but Route53 zone used in this example is not real).
        //      To enable SSL in ELB: uncomment this line, set "wait_for_validation = true" in ACM module and make sure that instance_protocol and lb_protocol are https or ssl.
        //      ssl_certificate_id = module.acm.this_acm_certificate_arn
        },
    ]

    health_check = {
        target              = "HTTP:80/"
        interval            = 30
        healthy_threshold   = 2
        unhealthy_threshold = 2
        timeout             = 5
    }

    access_logs = {
        bucket = aws_s3_bucket.logs.id
    }

    tags = {
        Owner       = "user"
        Environment = "dev"
    }
}
#ELB attachments
resource "aws_elb_attachment" "this" {
  count = 2

  elb      = module.elb.this_elb_id
  instance = aws_instance.hung_terraform_ubuntu.*.id[count.index]
}

#EC2 instance example


data "template_file" "bootstrap" {
  template = "${file("./bootstrap.tpl")}"
}
resource "aws_instance" "hung_terraform_ubuntu" {
  count                  = 3
#  availability_zone      = data.aws_availability_zones.available.names[count.index]
  ami                    = "ami-0ee0b284267ea6cde" //ubuntu 16.04 LTS
  instance_type          = "t2.micro"
  key_name               = "test_terraform_key"
  vpc_security_group_ids = [data.aws_security_group.default.id]
  subnet_id              = tolist(var.subnets_id_list)[count.index] #tolist(data.aws_subnet_ids.public_subnet.ids)[count.index]
  user_data              = data.template_file.bootstrap.rendered
  associate_public_ip_address = true
  tags = {
    Name = "Canh-Rau-Den-${count.index + 1}"
  }
}