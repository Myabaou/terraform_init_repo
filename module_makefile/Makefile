_MODULE = $1
_MAINFILE=${_MODULE}.tf
_VARIABLESFILE=${_MODULE}/variables.tf

define TF_MODULE
module "${_MODULE}" {
  source  = "./${_MODULE}"
  env     = var.env
  project = var.project
  ${_MODULE}_config = {
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

variable "${_MODULE}_config" {
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
	mkdir -p ${_MODULE}

ifeq ("$(wildcard $(_VARIABLESFILE))", "")
	echo "$${TF_VARIABLES}" > ${_VARIABLESFILE}
else
	echo "[INFO] ${_VARIABLESFILE} is found."
endif

	touch ${_MODULE}/main.tf
	touch ${_MODULE}/outputs.tf
	terraform init
delete-module:
	terraform apply -destroy -target module.${_MODULE}
	rm -r ${_MODULE}
	rm ${_MAINFILE}
