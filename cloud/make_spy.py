#!/usr/bin/env python
import boto3
import collections
import string
import random
import os, re
import glob
from botocore.exceptions import ClientError
from pprint import pprint
from datetime import datetime

# Start the instance with the settings you want,
# then get the JSON description of it by running:
#       aws ec2 describe-instances

def main():

    s = boto3.Session(region_name="us-west-1")
    ec2 = s.resource('ec2') # high level interface
    ec2c = s.client('ec2') # low level interface


    ###################################
    # Confirm Network Interface

    print("About to create network interface.")
    ui = input("Okay to proceed? (y/n): ")
    if(ui.lower()!='y' and ui.lower()!='yes'):
        print("Script will not proceed.")
        exit()


    ###################################
    # Network Interface:

    # Get the latest .file
    vpc_params_file = sorted(glob.glob("*.file"))[-1]

    network_json = make_network_json(vpc_params_file)

    print("Creating VPC %s_vpc"%(label))
    print("    Using VPC params in file %s..."%(vpc_params_file))

    try:
        net = ec2c.create_network_interface(**network_json)
    except ClientError as e:
        raise
 
    network_interface_id = net['NetworkInterface']['NetworkInterfaceId']

    print("    Success!")
    print("   VPC: %s (%s)"%(vpc_params['vpc_id'], vpc_params['vpc_label']))
    print("   Network Interface: %s"%(network_interface_id)
    print("   To delete this network interface:")
    print("")
    print("aws ec2 delete-network-interface --network-interface-id %s"%(network_interface_id))
    print("")
    print("")


    ###################################
    # Confirm Micro

    print("About to request spy node.")
    ui = input("Okay to proceed? (y/n): ")
    if(ui.lower()!='y' and ui.lower()!='yes'):
        print("Script will not proceed.")
        exit()


    ###################################
    # AWS Micro Node

    # Load the contents of this script 
    # (MUST be a bash script)
    # into the machine and run on boot.
    user_data_file = "user_data.sh"

    spy_json = make_spy_json(vpc_params_file, user_data_file, network_interface_id)

    print("Creating micro node")
    print("    Using user data file %s..."%(user_data_file))

    try:
        spy = ec2.create_instances(**spy_json)
    except ClientError as e:
        raise

    fname = datetime.now().strftime("spy_%Y-%m-%d_at_%H-%M-%S.file")

    with open(fname,'w') as f:
        print("network_interface_id: %s"%(net['NetworkInterface']['NetworkInterfaceId']), file=f)
        print("private_ip: %s"%(net['NetworkInterface']['PrivateIpAddress']),             file=f)
        print("vpc_id: %s"%(net['NetworkInterface']['VpcId']),                            file=f)

    # Include these lines next time this script is run,
    # there is a lot of useful info we should include from spy{}
    import pdb; pdb.set_trace()
    print(spy.keys())


def make_network_json(vpc_params_file):

    vpc_params = get_vpc_params(vpc_params_file)

    private_ip = re.sub('0\.0$','0.%d'%( random.randiint(100,250) ),vpc_params['base_ip']).strip()

    # https://boto3.readthedocs.io/en/stable/reference/services/ec2.html#EC2.Client.create_network_interface
    net_json = {
            "Groups": [ vpc_params["sg_id"] ],
            "PrivateIpAddress": private_ip,
            "SubnetId": vpc_params['subnet_id']
    }

    return net_json


def make_spy_json(vpc_params_file, user_data_file, network_interface_id):
    """
    Using the VPC parameters in filename,
    assemble a JSON that can be passed
    to AWS to request instances.
    """
    vpc_params = get_vpc_params(vpc_params_file)
    private_ip = re.sub('0\.0$','0.%d'%(111),vpc_params['base_ip']).strip()

    user_data = get_user_data(user_data_file)

    # https://boto3.readthedocs.io/en/stable/reference/services/ec2.html#EC2.ServiceResource.create_instances
    # https://stackoverflow.com/a/37868280/463213
    spy_json = {
                "InstanceType": "t2.micro",
                "ImageId": "ami-07585467",
                "UserData": user_data,
                "KeyName": "demo-key",
                "TagSpecifications": [{
                                "ResourceType":"instance",
                                "Tags": [{
                                            "Key": "name",
                                            "Value": vpc_params['label']+"_spy"
                                }]
                }],
                "Placement": {
                    "AvailabilityZone": "us-west-1a"
                },
                "BlockDeviceMappings": [
                    {
                        "DeviceName": "/dev/sdf",
                        "Ebs": {
                            "DeleteOnTermination": False,
                            "VolumeSize" : 30,
                            "VolumeType": "standard"
                        }
                    }
                ],
                "NetworkInterfaces": [
                    {
                        "AssociatePublicIpAddress": True,
                        'DeviceIndex': 0,
                        "DeleteOnTermination": True,
                        "Groups": [ vpc_params["sg_id"] ],
                        "SubnetId": vpc_params["subnet_id"]
                    }
                ],
                "MinCount" : 1,
                "MaxCount" : 1
                #"InstanceMarketOptions" : {
                #    'MarketType': 'on demand'
                #    #'MarketType': 'spot',
                #    #'SpotOptions': {
                #    #        #'SpotInstanceType': 'persistent',
                #    #        'BlockDurationMinutes': 360
                #    #}
                #}
    
    }
    
    return spy_json 

    
def get_vpc_params(vpc_params_file):
    """
    Extract and return a dictionary with
    the VPC parameters.
    """

    if(not os.path.isfile(vpc_params_file)):
        raise Exception("The specified VPC parameters file does not exist: %s"%(vpc_params_file))
    
    with open(vpc_params_file,'r') as f:
        lines = f.readlines()
    
    vpc_params = {}
    for line in lines:
        sp = line.split(": ")
        vpc_params[sp[0]] = sp[1].strip()
    
    # label
    # base_ip
    # vpc_id
    # vpc_label
    # subnet_id
    # sg_id
    # sg_label

    return vpc_params


def get_user_data(user_data_file):
    """
    Extract the contents of user_data.sh
    (must be a bash file starting with a shebang)
    https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/user-data.html#user-data-shell-scripts
    """
    if(not os.path.isfile(user_data_file)):
        raise Exception("The specified user data file does not exist: %s"%(vpc_params_file))

    user_data = None
    with open(user_data_file, 'r') as data:
        user_data = data.read()

    return user_data


if __name__=="__main__":
    main()
