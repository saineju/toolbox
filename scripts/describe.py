#!/usr/bin/env python3

import boto3
import json
import click
from tabulate import tabulate
import sys

def get_instances(ec2,ssm):
    instances_raw = ec2.describe_instances()
    instances = []
    instances_with_ssm = ssm.describe_instance_information()
    headers = ['Name','Id','Type','Key Name','State','Private IP','Public IP','SSM enabled','SSM ping status']
    for reservation in instances_raw['Reservations']:
        for instance in reservation['Instances']:
            data = []
            if 'Tags' in instance:
                name = ''.join([t['Value'] for t in instance['Tags'] if t['Key'] == 'Name'])
                data.append(name)
            else:
                data.append('N/A')
            data.append(instance.get('InstanceId','Unknown'))
            data.append(instance.get('InstanceType','Unknown'))
            data.append(instance.get('KeyName','Unknown'))
            state = instance.get('State')
            if (state):
                data.append(state.get('Name','Unknown'))
            else:
                data.append('Unknown')
            if 'PrivateIpAddress' in instance:
                data.append(instance['PrivateIpAddress'])
            else:
                data.append('N/A')
            if 'PublicIpAddress' in instance:
                data.append(instance['PublicIpAddress'])
            else:
                data.append('N/A')
            element = next((element for element in instances_with_ssm['InstanceInformationList'] if element['InstanceId'] == instance['InstanceId']),False)
            if element:
                data.append(True)
                data.append(element['PingStatus'])
            else:
                data.append(False)
                data.append('Unknown')
            instances.append(data)

    return(headers,instances)

def split_list(list,n):
    for i in range(0, len(list), n):
        yield list[i:i + n]

def get_clusters(ecs):
    cluster_list = ecs.list_clusters(maxResults=100)
    cluster_details = []
    clusters_split = list(split_list(cluster_list['clusterArns'],10))
    for clusters in clusters_split:
        temp = ecs.describe_clusters(clusters = clusters)
        cluster_details = cluster_details + temp['clusters']

    return(cluster_details)

def get_services(ecs,cluster):
    services = ecs.list_services(cluster = cluster, maxResults=100)
    service_details = []
    services_split = list(split_list(services['serviceArns'],10))
    for services in services_split:
        temp = ecs.describe_services(cluster = cluster, services = services)
        service_details = service_details + temp['services']

    return(service_details)

def get_tasks(ecs,cluster):
    tasks = ecs.list_tasks(cluster = cluster, maxResults=100)
    task_details = []
    tasks_split = list(split_list(tasks['taskArns'],10))
    for tasks in tasks_split:
        temp = ecs.describe_tasks(cluster = cluster, tasks = tasks)
        task_details = task_details + temp['tasks']

    return(task_details)

def get_container_instances(ecs,cluster):
    container_instances = ecs.list_container_instances(cluster = cluster, maxResults=100)
    container_instances_details = []
    container_instances_split = list(split_list(container_instances['containerInstanceArns'],10))
    for container_instances in container_instances_split:
        temp = ecs.describe_container_instances(cluster = cluster, containerInstances = container_instances)
        container_instances_details = container_instances_details + temp['containerInstances']

    return(container_instances_details)

def combine_services(ecs):
    service_data = []
    headers = ['Service','Status','Desired/Running/Pending','Cluster','Instances','CPU/Mem','Image tag']
    clusters = get_clusters(ecs)
    for cluster in clusters:
        services = get_services(ecs,cluster['clusterArn'])
        tasks = get_tasks(ecs,cluster['clusterArn'])
        container_instances = get_container_instances(ecs,cluster['clusterArn'])
        for service in services:
            data = []
            data.append(service['serviceName'])
            data.append(service['status'])
            data.append("{}/{}/{}".format(service['desiredCount'],service['runningCount'],service['pendingCount']))
            data.append(cluster['clusterName'])
            task_definition = service['taskDefinition']
            container_instance_arns = [ task['containerInstanceArn'] for task in tasks if task['taskDefinitionArn'] == task_definition ]
            if container_instance_arns:
                instance_ids = [ instance['ec2InstanceId'] for instance in container_instances if instance['containerInstanceArn'] in container_instance_arns ]
                data.append(",".join(instance_ids))
            else:
                data.append('N/A')
            task_definition_details = ecs.describe_task_definition(taskDefinition = task_definition)
            data.append("{}/{}".format(task_definition_details['taskDefinition']['containerDefinitions'][0]['cpu'],task_definition_details['taskDefinition']['containerDefinitions'][0]['memory']))
            data.append(task_definition_details['taskDefinition']['containerDefinitions'][0]['image'].split(":")[1])
            service_data.append(data)
    return(headers,service_data)

def describe_account(sts,iam):
    accounts = []
    account_identity = sts.get_caller_identity()
    account_aliases = iam.list_account_aliases(MaxItems=100)
    headers = ["Account Id","Account Aliases"]
    data = []
    data.append(account_identity['Account'])
    data.append(','.join(account_aliases['AccountAliases']))
    accounts.append(data)
    return(headers,accounts)

@click.command()
@click.option('--profile', '-p', envvar='AWS_PROFILE', prompt='Enter profile name', help='AWS Profile to use')
@click.option('--region', '-r', envvar='AWS_REGION', prompt='Enter Region', help='AWS Region')
@click.option('--service-name', help='Service name if describing services')
@click.argument('type', type=click.Choice(['instances','services','lbs','account']), default='instances',nargs=1)

def main(profile,region,type,service_name):
    session = boto3.Session(region_name = region, profile_name = profile)
    ec2 = session.client('ec2')
    ssm = session.client('ssm')
    ecs = session.client('ecs')
    iam = session.client('iam')
    sts = session.client('sts')

    data = ''
    headers = ''

    if type == 'instances':
        headers,data = get_instances(ec2,ssm)
    elif type == 'services':
        headers,data = combine_services(ecs)
    elif type == 'lbs':
        print("TBD")
    elif type == 'account':
        headers,data = describe_account(sts,iam)

    if data and headers:
        print(tabulate(data,headers))

if __name__ == '__main__':
    main()
