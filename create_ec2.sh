#!/bin/bash

set -euo pipefail

check_awscli(){
	if ! command -v aws &> /dev/null; then
		echo "AWS CLI is not installed, So installing..." >&2
		install_awscli
	fi
}

install_awscli(){
	echo "Installing AWS CLI vs on Linux..."
	
	# Download and install AWS CLI v2
	curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
	
	sudo apt-get install -y unzip &> /dev/null
	unzip -q awscliv2.zip
	sudo ./aws/install

	echo "Verify the aws cli installation...."
	aws --version
	
	echo"\nCleaning the installation....."
	rm -rf awscliv2.zip ./aws
}


wait_for_instance(){
	local instance_id="$1"
	echo "Waiting for instance $instance_id to be in running state...."

	while true; do
		state=$(aws ec2 describe-instances --instance-ids "$instance_id" --query 'Reservations[0].Instances[0].State.Name' --output text)
		if [[ "$state"=="running"]]; then
			echo "Instance $instance_id is now running."
			break
		fi
		sleep 10
	done
}


create_ec2_instance(){

	local ami_id="$1"
	local instance_type="$2"
	local key_name="$3"
	local subnet_id="$4"
	local security_group_ids="$5"
	local instance_name="$6"

	# Run AWS CLI command to create EC2 instance
	echo "Creating the ec2 instance......"
	instance_id=$(aws ec2 run-instances \
		--image-id "$ami_id" \
		--instance-type "$instance_type" \
		--key-name "$key_name" \
		--subnet-id "$subnet_id" \
		--security-group-ids "$Security_group_ids" \
		--tag-specifications "ResourceType=instance, Tags=[{Key=Name,Value=$instance_name}]"\
		--query 'Instances[0].InstanceId' \
		--output text
	)

	if [[ -z "$instance_id" ]]; then
		echo "Failed to create EC2 instance." >&2
		exit 1
	fi
	
 
	echo "Instance $instance_id created successfully."

	
	# Wait for the instance to be in running state
	echo "Waiting for instance to be at running state......"
	wait_for_instance "$instance_id"
}


main () {
	# check aws-cli
	check_awscli

	echo "Creating EC2 instance...."	
	#Specify the EC2 instance parameters
	AMI_ID=""
	INSTANCE_TYPE="t2.micro"
	KEY_NAME=""
	SUBNET_ID=""
	SECURITY_GROUP_IDS=""
	INSTANCE_NAME=""
	
	# Creating the EC2 instance with all configuration
	create_ec2_instance "$AMI_ID" "$INSTANCE_TYPE" "$KEY_NAME" "$SUBNET_ID" "$SECURITY_GROUP_IDS" "$INSTANCE_NAME"
	
	echo "EC2 instance creation completed..."
	
}

main "$@"



