_MODULE = $1
_MAINFILE=${_MODULE}.tf
_MODULE_DIR=../../modules/${_MODULE}
_VARIABLESFILE=${_MODULE_DIR}/variables.tf

define TF_MODULE
module "${_MODULE}" {
  source  = "${_MODULE_DIR}"
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


define TF_VARIABLES
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
export TF_VARIABLES



.PHONY: create-module delete-module

create-module:

ifeq ("$(wildcard $(_MAINFILE))", "")
	echo "$${TF_MODULE}" > ${_MAINFILE}
else
	echo "[INFO] ${_MAINFILE} is found."
endif
	mkdir -p ${_MODULE_DIR}

ifeq ("$(wildcard $(_VARIABLESFILE))", "")
	echo "$${TF_VARIABLES}" > ${_VARIABLESFILE}
else
	echo "[INFO] ${_VARIABLESFILE} is found."
endif

	touch ${_MODULE_DIR}/main.tf
	touch ${_MODULE_DIR}/outputs.tf
	terraform init
delete-module:
	terraform apply -destroy -target module.${_MODULE}
	rm -r ${_MODULE_DIR}
	rm ${_MAINFILE}
