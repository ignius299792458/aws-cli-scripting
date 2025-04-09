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
		if [[ "$state"=="running" ]]; then
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
		--security-group-ids "$security_group_ids" \
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



main() {
    # Check aws-cli first
    check_awscli

    # Default values
    AMI_ID=""
    INSTANCE_TYPE="t2.micro"
    KEY_NAME=""
    SUBNET_ID=""
    SECURITY_GROUP_IDS=""
    INSTANCE_NAME=""
    
    # Parse command-line arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --ami)
                AMI_ID="$2"
                shift 2
                ;;
            --type)
                INSTANCE_TYPE="$2"
                shift 2
                ;;
            --key)
                KEY_NAME="$2"
                shift 2
                ;;
            --subnet)
                SUBNET_ID="$2"
                shift 2
                ;;
            --sg)
                SECURITY_GROUP_IDS="$2"
                shift 2
                ;;
            --name)
                INSTANCE_NAME="$2"
                shift 2
                ;;
            *)
                echo "Unknown option: $1" >&2
                echo "Usage: $0 --ami AMI_ID --key KEY_NAME --subnet SUBNET_ID --sg SECURITY_GROUP_IDS --name INSTANCE_NAME [--type INSTANCE_TYPE]" >&2
                exit 1
                ;;
        esac
    done
    
    # Check for required parameters
    missing_params=()
    
    if [[ -z "$AMI_ID" ]]; then
        missing_params+=("AMI_ID (--ami)")
    fi
    
    if [[ -z "$KEY_NAME" ]]; then
        missing_params+=("KEY_NAME (--key)")
    fi
    
    if [[ -z "$SUBNET_ID" ]]; then
        missing_params+=("SUBNET_ID (--subnet)")
    fi
    
    if [[ -z "$SECURITY_GROUP_IDS" ]]; then
        missing_params+=("SECURITY_GROUP_IDS (--sg)")
    fi
    
    if [[ -z "$INSTANCE_NAME" ]]; then
        missing_params+=("INSTANCE_NAME (--name)")
    fi
    
    # If any required parameters are missing, exit with error
    if [[ ${#missing_params[@]} -gt 0 ]]; then
        echo "Error: Missing required parameters:" >&2
        for param in "${missing_params[@]}"; do
            echo "  - $param" >&2
        done
        echo "Usage: $0 --ami AMI_ID --key KEY_NAME --subnet SUBNET_ID --sg SECURITY_GROUP_IDS --name INSTANCE_NAME [--type INSTANCE_TYPE]" >&2
        exit 1
    fi
    
    echo "Creating EC2 instance...."
    echo "AMI ID: $AMI_ID"
    echo "Instance Type: $INSTANCE_TYPE"
    echo "Key Name: $KEY_NAME"
    echo "Subnet ID: $SUBNET_ID"
    echo "Security Group IDs: $SECURITY_GROUP_IDS"
    echo "Instance Name: $INSTANCE_NAME"
    
    # Creating the EC2 instance with all configuration
    create_ec2_instance "$AMI_ID" "$INSTANCE_TYPE" "$KEY_NAME" "$SUBNET_ID" "$SECURITY_GROUP_IDS" "$INSTANCE_NAME"
    
    echo "EC2 instance creation completed..."
}

main "$@"



