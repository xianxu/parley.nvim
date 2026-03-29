# Assemble sub-Makefiles
include Makefile.parley
include Makefile.workflow
-include .openshell/Makefile

.PHONY: help

help: help-parley help-workflow help-sandbox
	@true
