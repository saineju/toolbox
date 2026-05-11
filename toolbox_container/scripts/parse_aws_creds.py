#!/usr/bin/env python3

import csv
from sys import argv,exit
from os import path, getenv, remove, chmod
import configparser
from shutil import copy
from datetime import datetime 

homedir=getenv("HOME")
awscreds=homedir + '/.aws/credentials'

if len(argv) != 3:
    print("Usage: " + argv[0] + " <aws_keyfile> <profile_name>")
    print("For example: " + argv[0] + " ~/Downloads/accessKeys.csv my-profile-x")
    exit(1)

credfile=argv[1]
profile=argv[2]

def ask(question):
    valid=['y','n']
    answer=input(question)
    default='n'
    while answer.lower() not in valid:
        if not answer:
            answer=default
        elif answer not in valid:
            print("Sorry your answer needs to be 'y' or 'n'")
            answer=input("please try again: ")
    return answer

if path.isfile(credfile):
    with open(credfile, 'r') as csvfile:
        reader=csv.reader(csvfile, delimiter=',')
        for row in reader:
            if reader.line_num == 2:              
                access_key = row[0]
                secret_key = row[1]
                config=configparser.ConfigParser()
                if path.isfile(awscreds):
                    bakfile=awscreds + ".bak." + datetime.now().isoformat()
                    print("Creating backup of " + awscreds + " to " + bakfile)
                    copy (awscreds,bakfile)
                    config.read(awscreds)
                config.add_section(profile)
                config.set(profile,"aws_access_key_id",access_key)
                config.set(profile,"aws_secret_access_key",secret_key)
                with open(awscreds,'w') as credentials:
                    config.write(credentials)
                chmod(awscreds, 0o600)
                verify=configparser.ConfigParser()
                verify.read(awscreds)

                if profile in verify:
                    answer=ask("profile " + profile + " added successfully, shall i remove " + credfile + " -file now, or do you want to do it manually (y/N)?")
                    if answer == 'y':
                        print("alrighty, removing file..")
                        remove(credfile)
                    else:
                        print("ok, I'll leave removing for you then, but I recommend for you to delete the file ASAP")

                                        

