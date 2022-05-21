S3_DIR_NAME = 00_S3_tfstate
_ENV_TOPDIR=environments
AWS_PROFILE = $1
_WORKSPACE_TFVARS=${_DIRNAME}/${_ENV_WP}.tfvars
_WORKSPACE_DEF = terraform -chdir=${_DIRNAME} workspace select default
_MODULE = $1
_MODULE_MAIN_TF=${_MODULE}.tf
_MODULE_DIR=modules/${_MODULE}
_MODULE_VAR_TF=${_MODULE_DIR}/variables.tf
_TARGET = $1

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
  default = "Gourmet"      # 実行者のオーナー情報適宜変更
}

endef
export TF_VARIABLES


define TF_S3TFSTATE

#各環境のterraform.tfstate格納用S3の設定


# Resource
resource "aws_s3_bucket" "terraform_state" {
  bucket = "$${var.aws_profile}-terraform-state"
}


resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# 暗号化を有効
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}


resource "aws_s3_bucket_lifecycle_configuration" "terraform_state" {
  depends_on = [aws_s3_bucket_versioning.terraform_state]
  bucket     = aws_s3_bucket.terraform_state.id
  rule {
    id = "tfstateexpire"

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
    noncurrent_version_expiration {
      noncurrent_days = 100
    }
    status = "Enabled"
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


define TF_MODULE
module "${_MODULE}" {
  source  = "../../${_MODULE_DIR}"
  env     = var.env
  project = var.project
  default_config = {
  }

  option_config = {
  }

}

output "${_MODULE}-info" {
  value = module.${_MODULE}.*
}

endef
export TF_MODULE


define TF_MODULE_VARIABLES
# Variable
variable "project" {
}

variable "env" {
}

variable "default_config" {
}

variable "option_config" {
}
endef
export TF_MODULE_VARIABLES


# ディレクトリ名定義
ifeq ($(_ENV),prd)
_DIRNAME=${_ENV_TOPDIR}/production
endif
ifeq ($(_ENV),stg)
_DIRNAME=${_ENV_TOPDIR}/staging
endif
ifeq ($(_ENV),dev)
_DIRNAME=${_ENV_TOPDIR}/development
endif
ifeq ($(_ENV),common)
_DIRNAME=${_ENV_TOPDIR}/common
endif

ifeq ($(_DIRNAME),)
_DIRNAME=${_ENV_TOPDIR}/${_ENV}
endif

TERRAFORM_CMD=terraform -chdir=${_DIRNAME}
ROOT_BACKEND_TF=${_DIRNAME}/backend.tf
ROOT_VAR_TF=${_DIRNAME}/variables.tf
ROOT_MAIN_TF=${_DIRNAME}/main.tf



.PHONY: s3-tfstate-destroy s3-tfstate-init s3-tfstate-create s3-tfstate-show tf-init tf-destroy tf-apply tf-wp-create tf-wp-apply tf-wp-delete

envcheck:
ifeq ($(strip $(_ENV)),default)
	@echo "[WARN] ENV is Empty. usage: make tf-plan _ENV=stg ."
	@exit 1
else
	@echo "[INFO] ENV is Found."
	@exit 0
endif

tgcheck:
ifeq ($(strip $(_TARGET)),)
	@echo "[WARN]Target is Empty. usage: make plan _TARGET=[Module Name]."
	@exit 1
else
	@echo "[INFO]Target is Found."
	@exit 0
endif
_TARGET_SED := $(shell echo ${_TARGET} | sed "s/\[/\\\[\\\\\"/g" | sed "s/\]/\\\\\"\\\]/g" )

s3-tfstate-destroy: ## remove tfstate S3 Bucket
	terraform -chdir=${S3_DIR_NAME} apply -destroy
	rm -rf ${S3_DIR_NAME}

s3-tfstate-init: ## init tfstate S3 Bucket
	mkdir -p ${S3_DIR_NAME}

	@echo "$${TF_MAIN}" > ${S3_DIR_NAME}/main.tf
	@echo "$${TF_VARIABLES}" > ${S3_DIR_NAME}/variables.tf
	@echo "$${TF_S3TFSTATE}" > ${S3_DIR_NAME}/s3_tfstate.tf

	terraform -chdir=${S3_DIR_NAME} init
	terraform -chdir=${S3_DIR_NAME} plan
s3-tfstate-create: ## create tfstate S3 Bucket
	terraform -chdir=${S3_DIR_NAME} apply
s3-tfstate-show: ## show tfstate S3 Bucket
	terraform -chdir=${S3_DIR_NAME} show

tf-init:
	@mkdir -p ${_DIRNAME}

ifeq ("$(wildcard $(ROOT_BACKEND_TF))", "")
	@echo "$${TF_BACKEND}" > ${ROOT_BACKEND_TF}
else
	@echo "[INFO] ${ROOT_BACKEND_TF} is found. already exists."
endif

ifeq ("$(wildcard $(ROOT_VAR_TF))", "")
	@echo "$${TF_BACKEND}" > ${ROOT_VAR_TF}
else
	@echo "[INFO] ${ROOT_VAR_TF} is found. already exists."
endif

ifeq ("$(wildcard $(ROOT_MAIN_TF))", "")
	@echo "$${TF_BACKEND}" > ${ROOT_MAIN_TF}
else
	@echo "[INFO] ${ROOT_MAIN_TF} is found. already exists."
endif

	${TERRAFORM_CMD} init

tf-destroy:

	${TERRAFORM_CMD} apply -destroy
	rm -rfv ${_DIRNAME}

tf-allplan:
	@make envcheck
	${TERRAFORM_CMD} plan

tf-allapply:
	@make envcheck
	${TERRAFORM_CMD} apply
	@make tf-output

tf-list:
	@make envcheck
	${TERRAFORM_CMD} state list

tf-validate:
	@make envcheck
	${TERRAFORM_CMD} validate

tf-output:
	@make envcheck
	${TERRAFORM_CMD} output > ${_DIRNAME}/aws_info.txt

tf-lock:
	@make envcheck
	${TERRAFORM_CMD} providers lock -platform=darwin_amd64 -platform=darwin_arm64 -platform=linux_amd64 -platform=linux_arm64
tf-show:
	@make envcheck
	@make tgcheck
	${TERRAFORM_CMD} state show ${_TARGET_SED}
tf-import:
	@make envcheck
	@make tgcheck
	${TERRAFORM_CMD} import ${_TARGET_SED}
tf-plan:
	@make envcheck
	@make tgcheck
	${TERRAFORM_CMD} plan -target=${_TARGET_SED}
tf-apply:
	@make envcheck
	@make tgcheck
	${TERRAFORM_CMD} apply -target=${_TARGET_SED}


create-module:
	@make envcheck
ifeq ("$(wildcard $(_MODULE_MAIN_TF))", "")
	echo "$${TF_MODULE}" > ${_DIRNAME}/${_MODULE_MAIN_TF}
else
	echo "[INFO] ${_DIRNAME}/${_MODULE_MAIN_TF} is found."
endif
	mkdir -p ./${_MODULE_DIR}

ifeq ("$(wildcard $(_MODULE_VAR_TF))", "")
	echo "$${TF_MODULE_VARIABLES}" > ${_MODULE_VAR_TF}
else
	echo "[INFO] ${_MODULE_VAR_TF} is found."
endif

	touch ${_MODULE_DIR}/main.tf
	touch ${_MODULE_DIR}/outputs.tf
	@make tf-init

### WORKSPACE ###
tf-wp-create:
	${TERRAFORM_CMD} workspace new ${_ENV_WP}
ifeq ("$(wildcard $(_WORKSPACE_TFVARS))", "")
	echo "env = \"$${_ENV_WP}\"" > ${_WORKSPACE_TFVARS}
else
	echo "[INFO] ${_WORKSPACE_TFVARS} is found."
endif
	@${_WORKSPACE_DEF}
tf-wp-delete:
	${TERRAFORM_CMD} workspace select ${_ENV_WP}
	${TERRAFORM_CMD} apply -destroy -var-file ../${_WORKSPACE_TFVARS}
	@${_WORKSPACE_DEF}
	${TERRAFORM_CMD} workspace delete ${_ENV_WP}
	rm -f ${_WORKSPACE_TFVARS}
tf-wp-apply:
	${TERRAFORM_CMD} workspace select ${_ENV_WP}
	-${TERRAFORM_CMD} apply -var-file ../${_WORKSPACE_TFVARS}
	@${_WORKSPACE_DEF}

