#!/usr/bin/env python3

# Script to start and stop an EC2 instance on-demand and add your public IP
# address to a Security Group attached to it to allow remote access.

# Note: Security Group will be cleaned (i.e. all rules removed) with any
# action. Best to use one only for this purpose.

# To Do:
# - Accept more than one instance.
# - Accept more than one protocol/port to enable.
# - Pass protocol/port as parameter.

import boto3
import argparse
import subprocess

parser = argparse.ArgumentParser(description='Handle the status and access of '
                                             'an EC2 instance.')
parser.add_argument('action', choices=['start', 'stop'],
                    help='Starts/stops instance while granting/revoking '
                    'access.')
parser.add_argument('-i', '--instance-id', dest='instance_id', required=True,
                    help='ID of instance to act on.')
parser.add_argument('-s', '--securitygroup-id', dest='sg_id', required=True,
                    help='ID of the Scurity Group to allow access in.')
parser.add_argument('-p', '--profile', dest='profile',
                    help='Name of the AWS CLI profile to use.')
args = parser.parse_args()

session = boto3.Session(profile_name=args.profile)
client = session.client('ec2')


def get_ip():
    try:
        try:
            ext_ip = subprocess.check_output(['dig', 'TXT',
                                              '+time=2', '+short',
                                              'o-o.myaddr.l.google.com',
                                              '@ns1.google.com'],
                                             universal_newlines=True)
        except subprocess.CalledProcessError:
            print('Notice: Unable to obtain your external IP directly. '
                  'Retrying without specifying a name server.')
            ext_ip = subprocess.check_output(['dig', 'TXT',
                                              '+time=2', '+short',
                                              'o-o.myaddr.l.google.com'],
                                             universal_newlines=True)
    except subprocess.CalledProcessError:
        pass
    finally:
        if not ext_ip:
            print('Error: Unable to obtain your external IP!')
            raise SystemError
        ip_cidr = ext_ip.strip('[^\"]|[\"\n$]') + '/32'
        print('Your public IP CIDR is:', ip_cidr)
        return ip_cidr


def get_rules(sg_id):
    response = client.describe_security_groups(
        DryRun=False,
        GroupIds=[
            sg_id,
        ]
    )
    return response


def revoke_rules(sg_id, ip_permissions):
    response = client.revoke_security_group_ingress(
        DryRun=False,
        GroupId=sg_id,
        IpPermissions=ip_permissions
    )
    return response


def auth_ip(sg_id, ip_cidr):
    response = client.authorize_security_group_ingress(
        DryRun=False,
        GroupId=sg_id,
        IpProtocol='tcp',
        FromPort=3389,
        ToPort=3389,
        CidrIp=ip_cidr
    )
    return response


def start(instance_id):
    response = client.start_instances(
        InstanceIds=[
            instance_id,
        ],
        DryRun=False
    )
    return response


def stop(instance_id):
    response = client.stop_instances(
        InstanceIds=[
            instance_id,
        ],
        DryRun=False
    )
    return response


if args.action == 'start':
    ip_permissions =\
            get_rules(args.sg_id)['SecurityGroups'][0]['IpPermissions']
    if ip_permissions:
        revoke_rules(args.sg_id, ip_permissions)
    auth_ip(args.sg_id, get_ip())
    start(args.instance_id)
elif args.action == 'stop':
    ip_permissions =\
            get_rules(args.sg_id)['SecurityGroups'][0]['IpPermissions']
    if ip_permissions:
        revoke_rules(args.sg_id, ip_permissions)
    stop(args.instance_id)
