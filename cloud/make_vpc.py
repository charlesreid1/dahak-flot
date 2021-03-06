#!/usr/bin/env python
import boto3
import collections
import string
import random
from botocore.exceptions import ClientError
from pprint import pprint
from datetime import datetime

# Create/modify sec groups:
# https://gist.github.com/steder/1498451

# Create security group:
# https://github.com/awsdocs/aws-doc-sdk-examples/blob/3c396bc74bfc8c1d2503d316bd2b3be2d9630ae5/python/example_code/ec2/create_security_group.py

SecurityGroupRule = collections.namedtuple("SecurityGroupRule", ["ip_protocol", "from_port", "to_port", "cidr_ip", "src_group_name"])

VPCRule = collections.namedtuple("vpc_rule", ["vpc_ip", "subnet_ip"])

def main():
    s = boto3.Session(region_name="us-west-1")
    ec2 = s.resource('ec2') # high level interface
    ec2c = s.client('ec2') # low level interface



    ###################################
    # User Settings

    # allowed port/ip address combos
    ports = [22, 27017, 8081, 19999, 9090, 3000]
    addr = ['173.244.48.132/32']


    ###################################
    # Random Labels

    base_ip = random_ip()
    label = random_label()

    print("Random IP for VPC Network: %s"%(base_ip.format(addr=0)))
    print("Random Label for Asset Group: %s"%(label))
    print("\n")


    ###################################
    # Confirm

    print("About to create a VPC, subnet, anad security group.")
    ui = input("Okay to proceed? (y/n): ")
    if(ui.lower()!='y' and ui.lower()!='yes'):
        print("Script will not proceed.")
        exit()


    ###################################
    # VPC Settings:

    vpc_cidr = base_ip.format(addr=0)+"/16"
    subnet_cidr = base_ip.format(addr=0)+"/24"

    # vpc cidr block
    # vpc subnet cidr block
    vpc_rule = VPCRule( vpc_ip = vpc_cidr,
                        subnet_ip = subnet_cidr)

    print("Creating VPC %s_vpc"%(label))

    (vpc_id,subnet_id,vpc_label) = create_dahak_vpc(label, ec2, ec2c, vpc_rule)

    print("  Success!")
    print("   VPC: %s (%s)"%(vpc_id, vpc_label))
    print("  Subnet: (%s)"%(subnet_id))
    print("\n")

    ###################################
    # Security Group Settings:

    # add subnet ips to allowed group
    addr += ['%s/16'%(base_ip.format(addr=0))]

    ip_settings = {}
    for p in ports:
        ip_settings[p] = addr

    print("Creating security group %s_sg"%(label))

    (sg_id,sg_label) = create_dahak_security_group(label, ec2c, vpc_id, ip_settings)
    
    print("  Success!")
    print("  Security group: %s (%s)"%(sg_id, sg_label))
    print("\n")

    ###################################
    # Save VPC Info To File:

    # call api to get info about vpc networks
    # save info to json dotfiles
    # 
    # remember, focusing on a single subnet architecture,
    # so we don't need to bother with multiple vpcs.

    # Right now, this is okay.
    # Preferable method is to save 
    # the entire JSON, in case we want
    # more information down the road.
    fname = datetime.now().strftime("vpc_%Y-%m-%d_at_%H-%M-%S.file")
    with open(fname,'w') as f:
        print("label: %s"%(label)           ,file=f)
        print("base_ip: %s"%(base_ip.format(addr=0)), file=f)
        print("vpc_id: %s"%(vpc_id)         ,file=f)
        print("vpc_label: %s"%(vpc_label)   ,file=f)
        print("subnet_id: %s"%(subnet_id)   ,file=f)
        print("sg_id: %s"%(sg_id)           ,file=f)
        print("sg_label: %s"%(sg_label)     ,file=f)


def create_dahak_vpc(prefix, ec2, ec2c, vpc_rule):
    """
    Create dahak vpc
    """
    vpc_label = prefix + "_vpc"

    try:
        # First, create a VPC network
        vpc = ec2.create_vpc(CidrBlock = vpc_rule.vpc_ip)

        # Enable DNS on the VPC
        response = ec2c.modify_vpc_attribute(VpcId=vpc.vpc_id,
                                            EnableDnsSupport={"Value":True})
        response = ec2c.modify_vpc_attribute(VpcId=vpc.vpc_id,
                                            EnableDnsHostnames={"Value":True})

        # Create VPC subnet
        subnet = vpc.create_subnet(CidrBlock = vpc_rule.subnet_ip,
                                   AvailabilityZone = 'us-west-1a')

        # Craete a DHCP options set for the VPC to use
        # (amazon-provided DHCP)
        dhcp_options = ec2.create_dhcp_options(
                DhcpConfigurations = [{
                    'Key':'domain-name-servers',
                    'Values':['AmazonProvidedDNS']
                },
                {
                    'Key': 'domain-name',
                    'Values': ['us-west-1.compute.internal']
                }]
        )
        dhcp_options.associate_with_vpc(VpcId =   vpc.id)

        # Create an internet gateway attached to this VPC
        gateway = ec2.create_internet_gateway()
        gateway.attach_to_vpc(VpcId = vpc.id)

        #Create a Route table and add the route
        route_table = ec2c.create_route_table(VpcId=vpc.vpc_id)
        route_table_id = route_table['RouteTable']['RouteTableId']
        response = ec2c.create_route( DestinationCidrBlock = '0.0.0.0/0',
                                      RouteTableId = route_table_id,
                                      GatewayId = gateway.internet_gateway_id )

        return (vpc.id,subnet.id,vpc_label)

    except ClientError as e:
    
        print(e)


def create_dahak_security_group(prefix, ec2c, vpc_id, ip_settings):
    """
    Create dahak security group
    """
    label = prefix + "_sg"
    try:
        response = ec2c.create_security_group(GroupName = label,
                                             Description = 'This security group was autogenerated by boto',
                                             VpcId = vpc_id)

        security_group_id = response['GroupId']

        print('Created Security Group %s in VPC %s'%(security_group_id, vpc_id))
    
        ip_permissions = []
        for p in ip_settings.keys():
            d = dict(IpProtocol = 'tcp',
                     FromPort   = p,
                     ToPort     = p,
                     IpRanges   = [dict(CidrIp=ip) for ip in ip_settings[p]]
                    )
            ip_permissions.append(d)

        data = ec2c.authorize_security_group_ingress(
            GroupId = security_group_id,
            IpPermissions = ip_permissions)
    
        print('Ingress Successfully Set %s' % data)

        return (security_group_id,label)

    except ClientError as e:
    
        print(e)


def get_vpc_id(ec2):
    """
    Get VPC id from AWS API
    """
    response = ec2.describe_vpcs()
    return parse_vpc_response(response)


def parse_vpc_response(response,ix=0):
    """
    Parse the AWS API response 
    """
    vpc_id = response.get('Vpcs', [{}])[ix].get('VpcId', '')
    return vpc_id


def random_label():
    # Generate a random label to uniquely identify this group
    
    a1 = random.choices(string.ascii_lowercase,k=2)
    a2 = random.choices(string.digits,k=1)
    a3 = random.choices(string.ascii_lowercase,k=2)

    label = ''.join(a1+a2+a3)

    return label


def random_ip():
    """
    Return a random IP of the form
    10.*.0.0
    """
    block = random.randint(15,99)
    return "10.%d.0.{addr}"%(block)


if __name__=="__main__":
    main()

