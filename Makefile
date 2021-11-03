S3_DIR_NAME = 00_S3_tfstate
AWS_PROFILE = $1
_WORKSPACE_TFVARS=${_DIRNAME}/${_ENV_WP}.tfvars
_WORKSPACE_DEF = terraform -chdir=${_DIRNAME} workspace select default
# 環境の指定がない場合
ifeq ($(2),)
_ENV = default
else
_ENV = $2
endif

# PROJECTの指定がない場合はAWS_PROFILEと同値を設定する。
ifeq ($(3),)
_PROJECT = ${AWS_PROFILE}
else
_PROJECT = $3
endif

# AWS_PROFILEの指定がない場合はリージョン情報は取得しない。
ifeq ($(AWS_PROFILE),)
  _REGION := demmy
else
  _REGION := $(shell aws configure get region --profile ${AWS_PROFILE})
endif


define TF_VARIABLES
#各環境のterraform.tfstate格納用S3の設定

# Variable
variable "aws_profile" {
  default = "${AWS_PROFILE}"
}

variable "project" {
  default = "${_PROJECT}"
}

variable "env" {
  default = "${_ENV}"
}

variable "region" {
  default = "${_REGION}"
}

variable "owner" {
  default = "SRE"      # 実行者のオーナー情報適宜変更
}

endef
export TF_VARIABLES


define TF_S3TFSTATE

#各環境のterraform.tfstate格納用S3の設定


# Resource
resource "aws_s3_bucket" "terraform_state" {
  bucket = "$${var.aws_profile}-terraform-state"
  versioning {
    enabled = true
  }

  # 暗号化を有効
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  lifecycle_rule {
    enabled                                = true
    abort_incomplete_multipart_upload_days = 7

    noncurrent_version_expiration {
      days = 100
    }
  }
}

# Output
output "s3" {
  description = "S3 Bucket Name"
  value = [
    "S3 Bucket Name",
    aws_s3_bucket.terraform_state.bucket,
  ]
}
endef
export TF_S3TFSTATE


define TF_MAIN
provider "aws" {
  profile = var.aws_profile
  region  = var.region
    default_tags {
    tags = {
      Environment    = var.env     
      Owner          = var.owner   
      CmBillingGroup = "$${var.project}/$${var.env}"
      Terraform      = "True"
    }
  }
}

provider "aws" {
  profile = var.aws_profile
  region  = "us-east-1"
  alias   = "us-east"
    default_tags {
    tags = {
      Environment    = var.env     
      Owner          = var.owner       
      CmBillingGroup = "$${var.project}/$${var.env}" 
      Terraform      = "True"
    }
  }

}
endef
export TF_MAIN


define TF_BACKEND
##########################################
# - 変更項目
#required_version      terraform のVersion
#profile                     AWSのプロファイル名
#bucket                     tfstateファイルを格納するバケット名
#key                          tfstateファイル名
##########################################
terraform {
  required_version = ">= 1.0.10"
  backend "s3" {
    profile = "${AWS_PROFILE}"
    bucket  = "${AWS_PROFILE}-terraform-state"
    region  = "${_REGION}"
    key     = "${_DIRNAME}/terraform.tfstate"
    encrypt = true
  }
}
endef
export TF_BACKEND



# ディレクトリ名定義
ifeq ($(_ENV),prd)
_DIRNAME=production
endif
ifeq ($(_ENV),stg)
_DIRNAME=staging
endif
ifeq ($(_ENV),dev)
_DIRNAME=development
endif
ifeq ($(_ENV),common)
_DIRNAME=common
endif

ifeq ($(_DIRNAME),)
_DIRNAME=${_ENV}
endif

.PHONY: s3-tfstate-destroy s3-tfstate-init s3-tfstate-create s3-tfstate-show tf-init tf-destroy tf-apply tf-wp-create tf-wp-apply tf-wp-delete

s3-tfstate-destroy: ## remove tfstate S3 Bucket
	terraform -chdir=${S3_DIR_NAME} apply -destroy
	rm -rf ${S3_DIR_NAME}

s3-tfstate-init: ## init tfstate S3 Bucket
	mkdir -p ${S3_DIR_NAME}

	echo "$${TF_MAIN}" > ${S3_DIR_NAME}/main.tf
	echo "$${TF_VARIABLES}" > ${S3_DIR_NAME}/variables.tf
	echo "$${TF_S3TFSTATE}" > ${S3_DIR_NAME}/s3_tfstate.tf

	terraform -chdir=${S3_DIR_NAME} init
	terraform -chdir=${S3_DIR_NAME} plan
s3-tfstate-create: ## create tfstate S3 Bucket
	terraform -chdir=${S3_DIR_NAME} apply
s3-tfstate-show: ## show tfstate S3 Bucket
	terraform -chdir=${S3_DIR_NAME} show

tf-init:
	mkdir -p ${_DIRNAME}
	echo "$${TF_BACKEND}" > ${_DIRNAME}/backend.tf
	echo "$${TF_VARIABLES}" > ${_DIRNAME}/variables.tf
	echo "$${TF_MAIN}" > ${_DIRNAME}/main.tf

	terraform -chdir=${_DIRNAME} init
	cp module_makefile/readme.md ${_DIRNAME}/
	cp module_makefile/Makefile ${_DIRNAME}/

tf-destroy:

	terraform -chdir=${_DIRNAME} apply -destroy
	rm -rfv ${_DIRNAME}

tf-apply:
	terraform -chdir=${_DIRNAME} apply

tf-wp-create:
	terraform -chdir=${_DIRNAME} workspace new ${_ENV_WP}
ifeq ("$(wildcard $(_WORKSPACE_TFVARS))", "")
	echo "env = \"$${_ENV_WP}\"" > ${_WORKSPACE_TFVARS}
else
	echo "[INFO] ${_WORKSPACE_TFVARS} is found."
endif
	@${_WORKSPACE_DEF}
tf-wp-delete:
	terraform -chdir=${_DIRNAME} workspace select ${_ENV_WP}
	terraform -chdir=${_DIRNAME} apply -destroy -var-file ../${_WORKSPACE_TFVARS}
	@${_WORKSPACE_DEF}
	terraform -chdir=${_DIRNAME} workspace delete ${_ENV_WP}
	rm -f ${_WORKSPACE_TFVARS}
tf-wp-apply:
	terraform -chdir=${_DIRNAME} workspace select ${_ENV_WP}
	-terraform -chdir=${_DIRNAME} apply -var-file ../${_WORKSPACE_TFVARS}
	@${_WORKSPACE_DEF}
