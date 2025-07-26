#!/bin/bash
echo "project_id=\"$2\"" > terraform/terraform.tfvars
echo "environment=\"$1\"" >> terraform/terraform.tfvars
